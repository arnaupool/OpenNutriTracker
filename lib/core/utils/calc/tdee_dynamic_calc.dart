import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

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

    final daysSpan = windowSeries.last.date
        .difference(windowSeries.first.date)
        .inDays;
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

    final daysSpan = windowSeries.last.date
        .difference(windowSeries.first.date)
        .inDays;
    if (daysSpan == 0) return null;

    final weightChangeKg =
        windowSeries.last.trendWeightKg - windowSeries.first.trendWeightKg;

    return (weightChangeKg / daysSpan) * 7;
  }
}
