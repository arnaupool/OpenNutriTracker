import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

void main() {
  WeightTrendPoint trendPoint(DateTime date, double trendWeightKg) {
    return (
      date: date,
      rawWeightKg: trendWeightKg,
      trendWeightKg: trendWeightKg,
    );
  }

  group('estimateTdee', () {
    test('returns null with fewer than 2 trend points', () {
      final result = TdeeDynamicCalc.estimateTdee(
        trendSeries: [trendPoint(DateTime(2026, 1, 1), 80.0)],
        dailyIntakeKcal: {DateTime(2026, 1, 1): 2000},
      );
      expect(result, isNull);
    });

    test('returns null when there is no overlapping intake data', () {
      final series = List.generate(
        5,
        (i) => trendPoint(DateTime(2026, 1, 1 + i), 80.0),
      );
      final result = TdeeDynamicCalc.estimateTdee(
        trendSeries: series,
        dailyIntakeKcal: {},
      );
      expect(result, isNull);
    });

    test('stable trend weight: TDEE equals average intake exactly', () {
      final series = List.generate(
        8,
        (i) => trendPoint(DateTime(2026, 1, 1 + i), 80.0),
      );
      final intake = {
        for (var i = 0; i < 8; i++) DateTime(2026, 1, 1 + i): 2400.0,
      };

      final result = TdeeDynamicCalc.estimateTdee(
        trendSeries: series,
        dailyIntakeKcal: intake,
      );

      expect(result, closeTo(2400.0, 0.001));
    });

    test('reproduces the MacroFactor Fat Loss Handbook worked example: '
        '2500 kcal TDEE assumption, 2000 kcal/day intake, only 0.5 lb/week '
        'observed loss -> recalculated TDEE of 2250 kcal', () {
      // 0.5 lb/week = 0.5 * 0.453592 kg over 7 days.
      const observedLossKg = 0.5 * 0.453592;
      final series = [
        trendPoint(DateTime(2026, 1, 1), 80.0),
        trendPoint(DateTime(2026, 1, 8), 80.0 - observedLossKg),
      ];
      final intake = {
        DateTime(2026, 1, 1): 2000.0,
        DateTime(2026, 1, 8): 2000.0,
      };

      final result = TdeeDynamicCalc.estimateTdee(
        trendSeries: series,
        dailyIntakeKcal: intake,
        windowDays: 7,
      );

      expect(result, closeTo(2250.0, 1.0));
    });

    test('only uses the trailing windowDays when the series is longer', () {
      // 20 days flat at 80kg (irrelevant to the estimate), then a 2-day
      // window with a real 0.5kg loss (79.5 -> 79.0) and known intake —
      // only the last windowDays=2 should be used.
      final flatDays = List.generate(
        20,
        (i) => trendPoint(DateTime(2026, 1, 1 + i), 80.0),
      );
      final series = [
        ...flatDays,
        trendPoint(DateTime(2026, 1, 21), 79.5),
        trendPoint(DateTime(2026, 1, 22), 79.0),
      ];
      final intake = {
        DateTime(2026, 1, 21): 2200.0,
        DateTime(2026, 1, 22): 2200.0,
      };

      final result = TdeeDynamicCalc.estimateTdee(
        trendSeries: series,
        dailyIntakeKcal: intake,
        windowDays: 2,
      );

      // 0.5kg lost over 1 day span -> daily stored = -0.5 * kcalPerKgBodyMass.
      final expectedDailyStored = -0.5 * TdeeDynamicCalc.kcalPerKgBodyMass;
      expect(result, closeTo(2200.0 - expectedDailyStored, 0.5));
    });
  });

  group('weeklyChangeRateKg', () {
    test('returns null with fewer than 2 trend points', () {
      final result = TdeeDynamicCalc.weeklyChangeRateKg([
        trendPoint(DateTime(2026, 1, 1), 80.0),
      ]);
      expect(result, isNull);
    });

    test('computes kg/week from the trailing window', () {
      // Loses exactly 1kg over 10 days -> 0.7kg/week.
      final series = [
        trendPoint(DateTime(2026, 1, 1), 80.0),
        trendPoint(DateTime(2026, 1, 11), 79.0),
      ];

      final result = TdeeDynamicCalc.weeklyChangeRateKg(series, windowDays: 10);

      expect(result, closeTo(-0.7, 0.001));
    });

    test('positive rate for weight gain', () {
      final series = [
        trendPoint(DateTime(2026, 1, 1), 70.0),
        trendPoint(DateTime(2026, 1, 8), 70.7),
      ];

      final result = TdeeDynamicCalc.weeklyChangeRateKg(series, windowDays: 7);

      expect(result, closeTo(0.7, 0.001));
    });
  });
}
