import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

/// [TdeeDynamicCalc.estimateTdeeCarriedForward]'s result: the smoothed
/// TDEE, the day it was computed as of, the trend cut at that day, and
/// whether updates are currently paused for lack of logged intake.
typedef CarriedForwardTdee = ({
  double tdee,
  DateTime asOfDay,
  List<WeightTrendPoint> trend,
  bool isPaused,
});

class TdeeDynamicCalc {
  /// Energy density used to convert a change in trend body weight into an
  /// implied daily energy surplus/deficit. MacroFactor's Fat Loss
  /// Handbook cites the classic ~3500 kcal per lb of body-mass change;
  /// converted to kg (×2.20462) since this codebase's WeightLogEntity is
  /// metric-first.
  static const double kcalPerKgBodyMass = 3500 * 2.20462;

  /// Rolling window MacroFactor documents for its dynamic TDEE estimate —
  /// a single mislogged day degrades the estimate for roughly this long
  /// afterward.
  static const int defaultWindowDays = 21;

  /// Window MacroFactor documents for the weekly "change rate" metric.
  static const int changeRateWindowDays = 20;

  /// Estimates TDEE from real intake and the trend-weight-implied energy
  /// balance over a rolling window:
  ///
  /// `TDEE = average_intake − average_daily_energy_stored`
  ///
  /// where `average_daily_energy_stored` is derived from the change in
  /// [WeightTrendCalc] trend weight across the window (see
  /// [kcalPerKgBodyMass]) — this is the same reordering of the energy
  /// balance equation MacroFactor documents for its own dynamic
  /// expenditure calculation.
  ///
  /// [trendSeries] should already be the smoothed output of
  /// [WeightTrendCalc.computeTrend]. [dailyIntakeKcal] maps calendar day
  /// to real (not goal) kcal consumed that day; only days present in both
  /// the trend window and this map contribute to the intake average.
  ///
  /// Returns null when there isn't enough data for a meaningful estimate:
  /// fewer than 2 trend points, a zero-day window span, or no intake data
  /// overlapping the window.
  static double? estimateTdee({
    required List<WeightTrendPoint> trendSeries,
    required Map<DateTime, double> dailyIntakeKcal,
    int windowDays = defaultWindowDays,
  }) {
    if (trendSeries.length < 2) return null;

    final windowSeries = trendSeries.length > windowDays
        ? trendSeries.sublist(trendSeries.length - windowDays)
        : trendSeries;

    final daysSpan = CalendarDayCalc.daysBetween(
      windowSeries.first.date,
      windowSeries.last.date,
    );
    if (daysSpan == 0) return null;

    final weightChangeKg =
        windowSeries.last.trendWeightKg - windowSeries.first.trendWeightKg;
    final dailyStoredKcal = (weightChangeKg * kcalPerKgBodyMass) / daysSpan;

    final intakeValues = windowSeries
        .map((p) => dailyIntakeKcal[p.date])
        .whereType<double>()
        .toList();
    if (intakeValues.isEmpty) return null;

    final avgIntake =
        intakeValues.reduce((a, b) => a + b) / intakeValues.length;

    return avgIntake - dailyStoredKcal;
  }

  /// EWMA smoothing constant [estimateTdeeSmoothed] applies to the
  /// *sequence* of raw [estimateTdee] outputs. MacroFactor documents "an
  /// additional intelligent smoothing layer" on top of its raw energy-
  /// balance inference specifically "to avoid over-corrections if
  /// expenditure is fluctuating" (help.macrofactorapp.com, "How Should I
  /// Interpret Changes to my Energy Expenditure?") — their exact value is
  /// proprietary, so this reuses [WeightTrendCalc]'s own validated
  /// constant rather than inventing an unsourced number.
  static const double expenditureSmoothingAlpha = WeightTrendCalc.defaultAlpha;

  /// Smooths the day-by-day sequence of raw [estimateTdee] outputs with
  /// an EWMA — the same technique [WeightTrendCalc] applies to raw scale
  /// weight. [estimateTdee] alone recomputes a fresh point estimate from
  /// scratch on every call, with no memory of the previous estimate, so a
  /// single volatile day — or the transient while the trend is still
  /// catching up to a real change in trajectory — can move the displayed
  /// number by hundreds of kcal in a single step. This spreads that
  /// correction out across calls instead, matching MacroFactor's own
  /// documented behavior of the estimate "gradually improving" over the
  /// first weeks rather than jumping straight to each day's raw read.
  ///
  /// Smoothing is seeded to the first day a raw [estimateTdee] value
  /// exists (mirroring how [WeightTrendCalc.computeTrend] seeds its first
  /// point directly to raw weight) and carries forward from there, so an
  /// early gap in valid raw estimates doesn't reset it. Returns null only
  /// when no day in [trendSeries] ever produced a valid raw estimate.
  static double? estimateTdeeSmoothed({
    required List<WeightTrendPoint> trendSeries,
    required Map<DateTime, double> dailyIntakeKcal,
    int windowDays = defaultWindowDays,
    double alpha = expenditureSmoothingAlpha,
  }) {
    double? smoothed;
    for (var i = 1; i <= trendSeries.length; i++) {
      final raw = estimateTdee(
        trendSeries: trendSeries.sublist(0, i),
        dailyIntakeKcal: dailyIntakeKcal,
        windowDays: windowDays,
      );
      if (raw == null) continue;
      smoothed = smoothed == null ? raw : smoothed + alpha * (raw - smoothed);
    }
    return smoothed;
  }

  /// Intake history, in days before the as-of day, that
  /// [estimateTdeeCarriedForward] feeds into [estimateTdeeSmoothed] —
  /// enough slack above [defaultWindowDays] that a full window of real
  /// intake is available even if the as-of day itself isn't tracked yet.
  static const int intakeLookbackDays = 25;

  /// MacroFactor's V3 expenditure algorithm only pauses updates "if you
  /// have more than three days of missing nutrition data" in a seven-day
  /// period (https://macrofactor.com/expenditure-v3/).
  static const int pauseWindowDays = 7;
  static const int maxMissingDaysInPauseWindow = 3;

  /// The latest day, no later than [today] or the last [trendSeries]
  /// point, whose [pauseWindowDays]-day window ending on it has at most
  /// [maxMissingDaysInPauseWindow] days without logged intake. Null when
  /// no day in the trend qualifies.
  static DateTime? confidentAsOfDay({
    required List<WeightTrendPoint> trendSeries,
    required Map<DateTime, double> dailyIntakeKcal,
    required DateTime today,
  }) {
    if (trendSeries.isEmpty) return null;
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final lastTrendDay = trendSeries.last.date;
    var day = lastTrendDay.isBefore(todayAtMidnight)
        ? lastTrendDay
        : todayAtMidnight;
    final firstTrendDay = trendSeries.first.date;
    while (!day.isBefore(firstTrendDay)) {
      if (!_isPauseWindowShort(dailyIntakeKcal, day)) return day;
      // Calendar arithmetic, so a DST change can't move [day] off midnight.
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return null;
  }

  /// Whether the [pauseWindowDays]-day window ending on [windowEnd] has
  /// more than [maxMissingDaysInPauseWindow] days without logged intake.
  static bool _isPauseWindowShort(
    Map<DateTime, double> dailyIntakeKcal,
    DateTime windowEnd,
  ) {
    var missing = 0;
    for (var i = 0; i < pauseWindowDays; i++) {
      final d = DateTime(windowEnd.year, windowEnd.month, windowEnd.day - i);
      if ((dailyIntakeKcal[d] ?? 0) <= 0) {
        missing++;
      }
    }
    return missing > maxMissingDaysInPauseWindow;
  }

  /// [estimateTdeeSmoothed] as it stood on [confidentAsOfDay]: the trend
  /// cut at that day and intake limited to the [intakeLookbackDays] before
  /// it. While the user isn't logging, this returns the same value every
  /// day instead of drifting as the intake window slides, and after a gap
  /// it carries the last confident estimate forward rather than giving up,
  /// as MacroFactor does with its last "high confidence" expenditure
  /// (https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/).
  /// [isPaused] is true when the last [pauseWindowDays] days up to [today]
  /// themselves have too little logged intake, so the estimate isn't
  /// updating right now.
  static CarriedForwardTdee? estimateTdeeCarriedForward({
    required List<WeightTrendPoint> trendSeries,
    required Map<DateTime, double> dailyIntakeKcal,
    required DateTime today,
  }) {
    final asOfDay = confidentAsOfDay(
      trendSeries: trendSeries,
      dailyIntakeKcal: dailyIntakeKcal,
      today: today,
    );
    if (asOfDay == null) return null;

    final trend = trendSeries.where((p) => !p.date.isAfter(asOfDay)).toList();
    final lookbackStart = DateTime(
      asOfDay.year,
      asOfDay.month,
      asOfDay.day - intakeLookbackDays,
    );
    final intake = {
      for (final e in dailyIntakeKcal.entries)
        if (!e.key.isBefore(lookbackStart) && !e.key.isAfter(asOfDay))
          e.key: e.value,
    };
    final tdee = estimateTdeeSmoothed(
      trendSeries: trend,
      dailyIntakeKcal: intake,
    );
    if (tdee == null) return null;

    return (
      tdee: tdee,
      asOfDay: asOfDay,
      trend: trend,
      isPaused: _isPauseWindowShort(
        dailyIntakeKcal,
        DateTime(today.year, today.month, today.day),
      ),
    );
  }

  /// Trend points below this are too noisy to blend into the live goal
  /// at all — matches [defaultWindowDays]'s own reasoning about a 2-3 day
  /// estimate swinging wildly. Below this floor, [GetKcalGoalUsecase]
  /// uses the static formula outright.
  static const int minTrendPointsForDynamic = 7;

  /// Trend points at (or above) which the dynamic estimate is treated as
  /// fully calibrated and used outright, with no more static blend-in.
  /// Reuses [defaultWindowDays] — once a full rolling window's worth of
  /// real data exists, there's no more "cold start" left to correct for.
  /// Between [minTrendPointsForDynamic] and this, [GetKcalGoalUsecase]
  /// linearly ramps from the static formula to the dynamic estimate,
  /// matching MacroFactor's own documented "estimates gradually
  /// improving...for basically the entirety of the initial 30-day
  /// period" rather than snapping straight from static to dynamic the
  /// moment the floor is crossed.
  static const int fullyMatureTrendPoints = defaultWindowDays;

  /// How much the dynamic estimate should be trusted vs. blended with a
  /// static fallback, given [trendPoints] real trend-weight points: 0 at
  /// [minTrendPointsForDynamic] or fewer, 1 at [fullyMatureTrendPoints] or
  /// more, linear in between. Shared between [GetKcalGoalUsecase] (the
  /// live goal) and `StrategyPage` (its own display) so the two never
  /// disagree about what "calibrating" vs. "fully active" means.
  static double dynamicBlendWeight(int trendPoints) {
    const span = fullyMatureTrendPoints - minTrendPointsForDynamic;
    if (span <= 0) return 1.0;
    final progress = (trendPoints - minTrendPointsForDynamic) / span;
    return progress.clamp(0.0, 1.0);
  }

  /// The observed weekly rate of change in trend weight, in kg/week, over
  /// the last [windowDays] days of [trendSeries]. Positive means gaining,
  /// negative means losing. Returns null under the same insufficient-data
  /// conditions as [estimateTdee].
  static double? weeklyChangeRateKg(
    List<WeightTrendPoint> trendSeries, {
    int windowDays = changeRateWindowDays,
  }) {
    if (trendSeries.length < 2) return null;

    final windowSeries = trendSeries.length > windowDays
        ? trendSeries.sublist(trendSeries.length - windowDays)
        : trendSeries;

    final daysSpan = CalendarDayCalc.daysBetween(
      windowSeries.first.date,
      windowSeries.last.date,
    );
    if (daysSpan == 0) return null;

    final weightChangeKg =
        windowSeries.last.trendWeightKg - windowSeries.first.trendWeightKg;

    return (weightChangeKg / daysSpan) * 7;
  }
}
