import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

class GetKcalGoalUsecase {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;
  final WeightLogRepository _weightLogRepository;
  final TrackedDayRepository _trackedDayRepository;

  GetKcalGoalUsecase(
    this._userRepository,
    this._configRepository,
    this._weightLogRepository,
    this._trackedDayRepository,
  );

  /// Logged activities never raise the goal (FM-12). MacroFactor infers
  /// expenditure from intake and trend weight alone, without exercise or
  /// wearable data (https://macrofactor.com/wearables/), so exercise is
  /// already inside the observed TDEE; the static path covers it through
  /// the activity level chosen at onboarding.
  Future<double> getKcalGoal({
    UserEntity? userEntity,
    double? kcalUserAdjustment,
  }) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();

    final coreGoal = await _computeCoreGoal(user);
    return coreGoal + (config.userKcalAdjustment ?? 0);
  }

  /// TDEE (static or dynamic) plus whatever goal-direction adjustment
  /// applies — everything [CalorieGoalCalc.getTotalKcalGoal] used to
  /// compute in one shot, minus the trailing `kcalUserAdjustment` term,
  /// which [getKcalGoal] adds once, uniformly, on top of whichever path
  /// ran here.
  ///
  /// Blends static and dynamic linearly between
  /// [TdeeDynamicCalc.minTrendPointsForDynamic] (0% dynamic — too little
  /// data to trust it at all) and [TdeeDynamicCalc.fullyMatureTrendPoints]
  /// (100% dynamic) rather than snapping straight from one to the other
  /// the moment the floor is crossed. MacroFactor documents its own
  /// estimates "gradually improving" over the initial weeks, not jumping;
  /// a hard cutover here would otherwise show the user a sudden multi-
  /// hundred-kcal jump in their goal the day the count crosses the floor.
  Future<double> _computeCoreGoal(UserEntity user) async {
    final staticGoal = _computeStaticCoreGoal(user);

    final weightEntries = await _weightLogRepository.getAllEntries();
    final filled = WeightInterpolationCalc.fillGaps(weightEntries);
    final trend = WeightTrendCalc.computeTrend(filled);
    if (trend.length < TdeeDynamicCalc.minTrendPointsForDynamic) {
      return staticGoal;
    }

    final estimate = await _carriedForwardTdee(trend);
    if (estimate == null ||
        estimate.trend.length < TdeeDynamicCalc.minTrendPointsForDynamic) {
      return staticGoal;
    }

    final dynamicGoal = _computeDynamicCoreGoal(user, estimate.tdee, trend);
    final blendWeight = TdeeDynamicCalc.dynamicBlendWeight(
      estimate.trend.length,
    );
    return staticGoal + blendWeight * (dynamicGoal - staticGoal);
  }

  double _computeStaticCoreGoal(UserEntity user) {
    final baseAdjustment = CalorieGoalCalc.getKcalGoalAdjustment(
      user.goal,
      weeklyWeightGoalKg: user.weeklyWeightGoalKg,
    );
    final adjustment = CalorieGoalCalc.applyTargetWeightTaper(
      baseAdjustment: baseAdjustment,
      currentWeightKg: user.weightKG,
      targetWeightKg: user.targetWeightKg,
      goal: user.goal,
      taperEnabled: user.caloriesTaperEnabled,
    );
    return CalorieGoalCalc.getTdee(user) + adjustment;
  }

  /// The dynamic TDEE as of the last day with enough logged intake (FM-13,
  /// see [TdeeDynamicCalc.estimateTdeeCarriedForward]). Intake is read
  /// from the first trend day on, so a long gap can still carry the last
  /// confident estimate forward.
  Future<CarriedForwardTdee?> _carriedForwardTdee(
    List<WeightTrendPoint> trend,
  ) async {
    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    // TrackedDayDBO.day isn't always normalized to midnight (see
    // StrategyPage._load) — push the upper bound to the last instant of
    // today so a real time-of-day component on today's entry isn't
    // silently dropped.
    final endOfToday = todayAtMidnight
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayRepository.getTrackedDayByRange(
      trend.first.date,
      endOfToday,
    );
    final dailyIntakeKcal = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };
    return TdeeDynamicCalc.estimateTdeeCarriedForward(
      trendSeries: trend,
      dailyIntakeKcal: dailyIntakeKcal,
      today: today,
    );
  }

  /// The Fase Motor path, layered on [dynamicTdee].
  ///
  /// Phased, not a single formula, because the two pieces this composes
  /// (TdeeDynamicCalc, DynamicMaintenanceCalc) each model a different part
  /// of what MacroFactor actually does: far from goal, a rolling-window
  /// TDEE re-estimated fresh every call already reproduces the "tightens
  /// if you're losing slower than intended, loosens if faster" check-in
  /// behavior on its own — a slower-than-expected loss at a fixed deficit
  /// necessarily means the window's true TDEE estimate comes out lower
  /// than before, which lowers the derived goal without any extra logic
  /// here. Near goal (inside DynamicMaintenanceCalc's band), that same
  /// rate-driven deficit would overshoot, so the band's own gentle
  /// 0.15%/week nudge takes over instead.
  double _computeDynamicCoreGoal(
    UserEntity user,
    double dynamicTdee,
    List<WeightTrendPoint> trend,
  ) {
    if (user.goal == UserWeightGoalEntity.maintainWeight) {
      return dynamicTdee;
    }

    final targetWeightKg = user.targetWeightKg;
    if (targetWeightKg != null) {
      return DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: trend.last.trendWeightKg,
        goalWeightKg: targetWeightKg,
        tdeeKcal: dynamicTdee,
      );
    }

    // Lose/gain with no target weight set yet — same flat adjustment the
    // static path uses, just layered on the dynamic TDEE instead of the
    // static one. A bridge until the user sets a real target, at which
    // point DynamicMaintenanceCalc's band takes over above.
    final baseAdjustment = CalorieGoalCalc.getKcalGoalAdjustment(
      user.goal,
      weeklyWeightGoalKg: user.weeklyWeightGoalKg,
    );
    return dynamicTdee + baseAdjustment;
  }
}
