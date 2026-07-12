import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';

/// A single day's raw vs. smoothed ("trend") weight.
typedef WeightTrendPoint = ({
  DateTime date,
  double rawWeightKg,
  double trendWeightKg,
});

class WeightTrendCalc {
  /// Smoothing constant for the EWMA trend. Validated against
  /// `ykawanabe/mf-sync` — an independent reconstruction of MacroFactor's
  /// real trend weight from Apple Health data — whose README states this
  /// exact algorithm "reproduce[s] MacroFactor's trend to a few grams".
  /// It also matches the classic constant from *The Hacker's Diet* (the
  /// origin of this smoothing approach) and the value used by Libra, the
  /// open-source Android weight tracker. See the Fase Motor plan for the
  /// full comparison across sources.
  static const double defaultAlpha = 0.1;

  /// Computes the exponentially-weighted moving average "trend weight"
  /// over a gap-filled daily series (see [WeightInterpolationCalc.fillGaps]
  /// — this must run on a series with no missing days, since each step
  /// assumes exactly one day passed since the previous point).
  ///
  /// `trend[t] = trend[t-1] + alpha * (weight[t] - trend[t-1])`
  ///
  /// The first point seeds the trend directly to its own raw weight —
  /// there is no prior trend to smooth against yet, matching how
  /// mf-sync's implementation handles the first reading.
  static List<WeightTrendPoint> computeTrend(
    List<InterpolatedWeightPoint> filledSeries, {
    double alpha = defaultAlpha,
  }) {
    assert(alpha > 0 && alpha <= 1, 'alpha must be in (0, 1]');

    if (filledSeries.isEmpty) return [];

    final result = <WeightTrendPoint>[];
    var trend = filledSeries.first.weightKg;
    result.add((
      date: filledSeries.first.date,
      rawWeightKg: filledSeries.first.weightKg,
      trendWeightKg: trend,
    ));

    for (var i = 1; i < filledSeries.length; i++) {
      final raw = filledSeries[i].weightKg;
      trend = trend + alpha * (raw - trend);
      result.add((
        date: filledSeries[i].date,
        rawWeightKg: raw,
        trendWeightKg: trend,
      ));
    }

    return result;
  }
}
