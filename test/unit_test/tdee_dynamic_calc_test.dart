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

  group('estimateTdeeSmoothed', () {
    test('returns null when no day ever produces a valid raw estimate', () {
      final result = TdeeDynamicCalc.estimateTdeeSmoothed(
        trendSeries: [trendPoint(DateTime(2026, 1, 1), 80.0)],
        dailyIntakeKcal: {},
      );
      expect(result, isNull);
    });

    test('stable trend weight: matches raw estimateTdee exactly (a constant '
        'series has nothing to smooth away)', () {
      final series = List.generate(
        8,
        (i) => trendPoint(DateTime(2026, 1, 1 + i), 80.0),
      );
      final intake = {
        for (var i = 0; i < 8; i++) DateTime(2026, 1, 1 + i): 2400.0,
      };

      final result = TdeeDynamicCalc.estimateTdeeSmoothed(
        trendSeries: series,
        dailyIntakeKcal: intake,
      );

      expect(result, closeTo(2400.0, 0.001));
    });

    test('dampens a single day\'s raw jump instead of snapping straight to '
        'it — MacroFactor documents an equivalent "smoothing layer...to '
        'avoid over-corrections"', () {
      // 15 flat days at 80kg (raw TDEE == the flat 2400 intake every
      // day, since weightChangeKg is 0 for any window ending inside
      // the flat run) seed the smoothed accumulator at exactly 2400.
      // Day 16 introduces a real 1kg drop, which on its own would
      // raise the *raw*, single-window estimate to ~2914 kcal.
      final flatDays = List.generate(
        15,
        (i) => trendPoint(DateTime(2026, 1, 1 + i), 80.0),
      );
      final series = [...flatDays, trendPoint(DateTime(2026, 1, 16), 79.0)];
      final intake = {
        for (var i = 0; i < 16; i++) DateTime(2026, 1, 1 + i): 2400.0,
      };

      final raw = TdeeDynamicCalc.estimateTdee(
        trendSeries: series,
        dailyIntakeKcal: intake,
      )!;
      final smoothed = TdeeDynamicCalc.estimateTdeeSmoothed(
        trendSeries: series,
        dailyIntakeKcal: intake,
      )!;

      // Closed-form: dailyStored = -1kg * kcalPerKgBodyMass / 15 days;
      // raw = 2400 - dailyStored.
      final expectedDailyStored = -1.0 * TdeeDynamicCalc.kcalPerKgBodyMass / 15;
      final expectedRaw = 2400.0 - expectedDailyStored;
      expect(raw, closeTo(expectedRaw, 0.5));

      // Smoothed accumulator was flat at 2400 through day 15, so day
      // 16 moves it only alpha (10%) of the way to the new raw value.
      final expectedSmoothed =
          2400.0 +
          TdeeDynamicCalc.expenditureSmoothingAlpha * (expectedRaw - 2400.0);
      expect(smoothed, closeTo(expectedSmoothed, 0.5));

      // The whole point: smoothed sits much closer to the pre-existing
      // 2400 baseline than the raw, single-day-reactive estimate does.
      expect((smoothed - 2400.0).abs(), lessThan((raw - 2400.0).abs()));
    });
  });

  group('dynamicBlendWeight', () {
    test('is 0 at or below the noise floor', () {
      expect(TdeeDynamicCalc.dynamicBlendWeight(2), 0.0);
      expect(
        TdeeDynamicCalc.dynamicBlendWeight(
          TdeeDynamicCalc.minTrendPointsForDynamic,
        ),
        0.0,
      );
    });

    test('is 1 at or above full maturity', () {
      expect(
        TdeeDynamicCalc.dynamicBlendWeight(
          TdeeDynamicCalc.fullyMatureTrendPoints,
        ),
        1.0,
      );
      expect(TdeeDynamicCalc.dynamicBlendWeight(365), 1.0);
    });

    test('is linear in between', () {
      final midpoint =
          (TdeeDynamicCalc.minTrendPointsForDynamic +
              TdeeDynamicCalc.fullyMatureTrendPoints) ~/
          2;
      expect(TdeeDynamicCalc.dynamicBlendWeight(midpoint), closeTo(0.5, 0.05));
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
