import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

void main() {
  InterpolatedWeightPoint point(DateTime date, double weightKg) {
    return (date: date, weightKg: weightKg, isInterpolated: false);
  }

  test('empty series returns empty trend', () {
    expect(WeightTrendCalc.computeTrend([]), isEmpty);
  });

  test('first point seeds the trend to its own raw weight', () {
    final result = WeightTrendCalc.computeTrend([
      point(DateTime(2026, 1, 1), 80.0),
    ]);

    expect(result, hasLength(1));
    expect(result.single.rawWeightKg, 80.0);
    expect(result.single.trendWeightKg, 80.0);
  });

  test('constant weight series produces a flat, unchanged trend', () {
    final series = List.generate(
      10,
      (i) => point(DateTime(2026, 1, 1 + i), 80.0),
    );

    final result = WeightTrendCalc.computeTrend(series);

    expect(result.every((p) => p.trendWeightKg == 80.0), isTrue);
  });

  test('step response follows the closed-form EWMA formula', () {
    // Seed at 80kg, then step to 90kg and hold. With alpha=0.1 the trend
    // on day n (n=0 at the step) is 90 - 10*(0.9)^n — the standard EWMA
    // step-response formula, since trend_0 = 80 = 90 - 10*0.9^0.
    final series = [
      point(DateTime(2026, 1, 1), 80.0),
      ...List.generate(9, (i) => point(DateTime(2026, 1, 2 + i), 90.0)),
    ];

    final result = WeightTrendCalc.computeTrend(series);

    for (var n = 0; n < result.length; n++) {
      final expected = 90 - 10 * math.pow(0.9, n);
      expect(
        result[n].trendWeightKg,
        closeTo(expected, 0.0001),
        reason: 'day $n',
      );
    }
    // Concretely: day 1 (first day after the step) is 80 + 0.1*10 = 81.
    expect(result[1].trendWeightKg, closeTo(81.0, 0.0001));
  });

  test('a single-day anomaly is damped, not fully reflected in the trend', () {
    final series = [
      point(DateTime(2026, 1, 1), 80.0),
      point(DateTime(2026, 1, 2), 80.0),
      point(DateTime(2026, 1, 3), 80.0),
      point(DateTime(2026, 1, 4), 95.0), // one-day water-weight spike
      point(DateTime(2026, 1, 5), 80.0),
      point(DateTime(2026, 1, 6), 80.0),
    ];

    final result = WeightTrendCalc.computeTrend(series);
    final spikeDayTrend = result[3].trendWeightKg;

    // trend should move toward 95 but nowhere near it (80 + 0.1*15 = 81.5).
    expect(spikeDayTrend, closeTo(81.5, 0.0001));
    expect(spikeDayTrend, lessThan(85.0));

    // and it should relax back down afterward, not stay elevated.
    expect(result.last.trendWeightKg, lessThan(spikeDayTrend));
  });

  test('alpha=1.0 disables smoothing entirely (trend tracks raw exactly)', () {
    final series = [
      point(DateTime(2026, 1, 1), 80.0),
      point(DateTime(2026, 1, 2), 76.0),
      point(DateTime(2026, 1, 3), 90.0),
    ];

    final result = WeightTrendCalc.computeTrend(series, alpha: 1.0);

    for (final p in result) {
      expect(p.trendWeightKg, p.rawWeightKg);
    }
  });

  test('rawWeightKg always mirrors the input series unchanged', () {
    final series = [
      point(DateTime(2026, 1, 1), 80.0),
      point(DateTime(2026, 1, 2), 79.4),
      point(DateTime(2026, 1, 3), 79.9),
    ];

    final result = WeightTrendCalc.computeTrend(series);

    expect(result.map((p) => p.rawWeightKg).toList(), [80.0, 79.4, 79.9]);
  });
}
