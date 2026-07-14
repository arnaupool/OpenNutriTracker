import 'package:collection/collection.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
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
  final UserActivityRepository _userActivityRepository;
  final WeightLogRepository _weightLogRepository;
  final TrackedDayRepository _trackedDayRepository;

  // Fase Motor: minimum trend points before the dynamic path is trusted to
  // actually govern the goal. TdeeDynamicCalc.estimateTdee itself only
  // needs 2 to return a number at all, but a 2-3 day estimate swings the
  // goal around wildly — this is a stricter, separate bar for "trust it
  // enough to replace the static fallback," not a change to the estimator.
  static const int _minTrendPointsForDynamic = 7;

  // Matches StrategyPage's lookback — enough slack above
  // TdeeDynamicCalc.defaultWindowDays (21) that a full window of real
  // intake is available even if today hasn't been tracked yet.
  static const int _intakeLookbackDays = 25;

  GetKcalGoalUsecase(
    this._userRepository,
    this._configRepository,
    this._userActivityRepository,
    this._weightLogRepository,
    this._trackedDayRepository,
  );

  Future<double> getKcalGoal({
    UserEntity? userEntity,
    double? totalKcalActivitiesParam,
    double? kcalUserAdjustment,
  }) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    final totalKcalActivities =
        totalKcalActivitiesParam ??
        (await _userActivityRepository.getAllUserActivityByDate(
          DateTime.now(),
        )).map((activity) => activity.burnedKcal).toList().sum;

    final coreGoal = await _computeCoreGoal(user);
    return coreGoal + (config.userKcalAdjustment ?? 0) + totalKcalActivities;
  }

  /// TDEE (static or dynamic) plus whatever goal-direction adjustment
  /// applies — everything [CalorieGoalCalc.getTotalKcalGoal] used to
  /// compute in one shot, minus the trailing `kcalUserAdjustment` /
  /// activities terms, which [getKcalGoal] adds once, uniformly, on top
  /// of whichever path ran here.
  Future<double> _computeCoreGoal(UserEntity user) async {
    final dynamicGoal = await _computeDynamicCoreGoal(user);
    if (dynamicGoal != null) return dynamicGoal;

    // No dynamic estimate available (new user, not enough weigh-ins yet,
    // or no logged intake overlapping the window) — exactly today's
    // static formula, unchanged.
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

  /// The Fase Motor path — null whenever there isn't enough real history
  /// to trust it, in which case [_computeCoreGoal] falls back to static.
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
  Future<double?> _computeDynamicCoreGoal(UserEntity user) async {
    final weightEntries = await _weightLogRepository.getAllEntries();
    final filled = WeightInterpolationCalc.fillGaps(weightEntries);
    final trend = WeightTrendCalc.computeTrend(filled);
    if (trend.length < _minTrendPointsForDynamic) return null;

    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final lookbackStart = todayAtMidnight.subtract(
      const Duration(days: _intakeLookbackDays),
    );
    // TrackedDayDBO.day isn't always normalized to midnight (see
    // StrategyPage._load) — push the upper bound to the last instant of
    // today so a real time-of-day component on today's entry isn't
    // silently dropped.
    final endOfToday = todayAtMidnight
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayRepository.getTrackedDayByRange(
      lookbackStart,
      endOfToday,
    );
    final dailyIntakeKcal = {
      for (final d in trackedDays)
        DateTime(d.day.year, d.day.month, d.day.day): d.caloriesTracked,
    };

    final dynamicTdee = TdeeDynamicCalc.estimateTdee(
      trendSeries: trend,
      dailyIntakeKcal: dailyIntakeKcal,
    );
    if (dynamicTdee == null) return null;

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
