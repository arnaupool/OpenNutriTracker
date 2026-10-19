import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

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
  ///
  /// The goal is the one fixed at the last weekly check-in (FM-15):
  /// MacroFactor's check-ins are weekly and its calorie recommendations are
  /// for the next week
  /// (https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules,
  /// https://help.macrofactorapp.com/en/articles/20-expenditure). New
  /// weigh-ins and intake only reach it through [completeCheckIn]; the
  /// first call with no check-in yet starts the program, as creating a
  /// MacroFactor program sets targets from the current expenditure
  /// (https://help.macrofactorapp.com/en/articles/205-why-does-my-new-program-have-slightly-different-calorie-and-macronutrient-targets-than-my-old-program-even-though-i-didnt-change-my-goal).
  Future<double> getKcalGoal({
    UserEntity? userEntity,
    double? kcalUserAdjustment,
  }) async {
    final config = await _configRepository.getConfig();
    final stored = await _userRepository.getUserData();
    final coreGoal =
        stored.checkInCoreGoalKcal ?? await restartProgram(userEntity: userEntity);
    return coreGoal + (config.userKcalAdjustment ?? 0);
  }

  /// What a check-in today would set: the live engine output, plus the
  /// user's manual kcal adjustment.
  Future<double> getRecommendedKcalGoal({UserEntity? userEntity}) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    return await _computeCoreGoal(user) + (config.userKcalAdjustment ?? 0);
  }

  /// Weekly check-in status: the next check-in is the first day after the
  /// last one that falls on the chosen weekday, and it is due from then on.
  Future<({bool isDue, DateTime nextCheckInDay, int weekday})?>
  getCheckInStatus() async {
    final user = await _userRepository.getUserData();
    final last = user.lastCheckInDay;
    if (last == null) return null;
    final weekday = user.checkInWeekday ?? last.weekday;
    final next = nextCheckInDay(last, weekday);
    return (
      isDue: !_today().isBefore(next),
      nextCheckInDay: next,
      weekday: weekday,
    );
  }

  /// The first day after [lastCheckInDay] that falls on [weekday].
  /// Calendar arithmetic, not Duration, so a DST change in between can't
  /// shift the result off midnight.
  static DateTime nextCheckInDay(DateTime lastCheckInDay, int weekday) {
    for (var i = 1; ; i++) {
      final day = DateTime(
        lastCheckInDay.year,
        lastCheckInDay.month,
        lastCheckInDay.day + i,
      );
      if (day.weekday == weekday) return day;
    }
  }

  /// Applies the check-in: today's recommendation becomes the goal.
  Future<void> completeCheckIn() async {
    await restartProgram();
  }

  /// Declines the check-in: MacroFactor applies no recommendation then
  /// (art. 247), so the goal stays and the next one is a week away.
  Future<void> skipCheckIn() async {
    final user = await _userRepository.getUserData();
    user.lastCheckInDay = _today();
    user.checkInWeekday ??= user.lastCheckInDay!.weekday;
    await _userRepository.updateUserData(user);
  }

  Future<void> setCheckInWeekday(int weekday) async {
    final user = await _userRepository.getUserData();
    user.checkInWeekday = weekday;
    await _userRepository.updateUserData(user);
  }

  /// Sets the goal from the live engine now and records today as the
  /// check-in day. Used for the first goal, for completed check-ins, and
  /// when the goal or target weight changes (a new MacroFactor program is
  /// computed from the current expenditure, art. 205). Returns the new
  /// core goal (before the manual kcal adjustment).
  Future<double> restartProgram({UserEntity? userEntity}) async {
    final stored = await _userRepository.getUserData();
    final core = await _computeCoreGoal(userEntity ?? stored);
    stored
      ..checkInCoreGoalKcal = core
      ..lastCheckInDay = _today();
    stored.checkInWeekday ??= stored.lastCheckInDay!.weekday;
    await _userRepository.updateUserData(stored);
    return core;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
    // A rate picked in Profile (FM-14) also drives the static bootstrap;
    // without one, the original flat/kg-per-week adjustment stays.
    final ratePct = user.weeklyRatePct;
    final baseAdjustment =
        ratePct == null || user.goal == UserWeightGoalEntity.maintainWeight
        ? CalorieGoalCalc.getKcalGoalAdjustment(
            user.goal,
            weeklyWeightGoalKg: user.weeklyWeightGoalKg,
          )
        : (user.goal == UserWeightGoalEntity.loseWeight ? -1 : 1) *
              GoalRateCalc.rateKcalPerDay(
                ratePct: ratePct,
                weightKg: user.weightKG,
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
    final endOfToday = CalendarDayCalc.addDays(
      todayAtMidnight,
      1,
    ).subtract(const Duration(milliseconds: 1));
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

  /// The Fase Motor path: [dynamicTdee] plus [GoalRateCalc.adjustment] —
  /// the chosen % of body weight per week while a lose/gain goal is short
  /// of its target, MacroFactor's dynamic maintenance band otherwise.
  /// Recomputing the TDEE over the rolling window is what reproduces the
  /// "tightens if you're losing slower than intended, loosens if faster"
  /// check-in behavior: a slower-than-expected loss at a fixed deficit
  /// means the window's TDEE estimate comes out lower than before.
  double _computeDynamicCoreGoal(
    UserEntity user,
    double dynamicTdee,
    List<WeightTrendPoint> trend,
  ) {
    final adjustment = GoalRateCalc.adjustment(
      goal: user.goal,
      trendWeightKg: trend.last.trendWeightKg,
      targetWeightKg: user.targetWeightKg,
      ratePct: GoalRateCalc.effectiveRatePct(user),
    );
    return dynamicTdee + adjustment.adjustmentKcal;
  }
}
