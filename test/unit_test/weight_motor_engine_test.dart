import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

void main() {
  WeightLogEntity entry(DateTime date, double weightKg) =>
      WeightLogEntity(date: date, weightKg: weightKg);

  group('Fase Motor end-to-end: interpolation -> trend -> dynamic TDEE -> '
      'macros -> Dynamic Maintenance', () {
    test('golden path: a real step change, cross-checked against an '
        'independent closed-form derivation at every stage', () {
      // Day 1 at 80kg, then a clean step up to 84kg held for the rest of
      // the month — the same shape FM-02's own step-response test uses,
      // chosen here specifically because it has an exact closed-form
      // trend value at every day (trend_t = target - (target-seed)*0.9^t),
      // so every downstream stage can be checked against a precise
      // expected number instead of a sanity bound. This test is about
      // proving the *wiring* between stages is correct (right window,
      // right date math, right averaging) — not re-proving the EWMA
      // formula itself, that's FM-02's job.
      const seedWeight = 80.0;
      const stepWeight = 84.0;
      const dailyIntakeKcal = 3000.0;
      const heightCm = 178.0;
      const proteinGPerKg = 1.8;

      final rawEntries = [
        entry(DateTime(2026, 1, 1), seedWeight),
        for (var day = 2; day <= 22; day++)
          entry(DateTime(2026, 1, day), stepWeight),
      ];
      final intake = {
        for (var day = 1; day <= 22; day++)
          DateTime(2026, 1, day): dailyIntakeKcal,
      };

      // Stage 1: interpolation. No gaps here, so this should be a
      // straight passthrough — still worth asserting, since a silent
      // day-count mismatch at the first join would corrupt every later
      // stage.
      final filled = WeightInterpolationCalc.fillGaps(rawEntries);
      expect(filled, hasLength(22));
      expect(filled.every((p) => !p.isInterpolated), isTrue);

      // Stage 2: trend, cross-checked against the closed-form EWMA step
      // formula rather than a hand-typed decimal.
      final trend = WeightTrendCalc.computeTrend(filled);
      expect(trend, hasLength(22));

      num expectedTrendAtStep(int t) =>
          stepWeight - (stepWeight - seedWeight) * math.pow(0.9, t);

      for (var t = 0; t < trend.length; t++) {
        expect(
          trend[t].trendWeightKg,
          closeTo(expectedTrendAtStep(t), 1e-9),
          reason: 'day index $t',
        );
      }

      // Stage 3: dynamic TDEE. The default 21-day window over this
      // 22-point series takes the trailing 21 points (Jan 2-22),
      // spanning 20 calendar days.
      final tdee = TdeeDynamicCalc.estimateTdee(
        trendSeries: trend,
        dailyIntakeKcal: intake,
      );
      expect(tdee, isNotNull);
      final tdeeValue = tdee!;

      final expectedWeightChangeKg =
          expectedTrendAtStep(21) - expectedTrendAtStep(1);
      final expectedDailyStoredKcal =
          (expectedWeightChangeKg * TdeeDynamicCalc.kcalPerKgBodyMass) / 20;
      final expectedTdee = dailyIntakeKcal - expectedDailyStoredKcal;

      expect(tdeeValue, closeTo(expectedTdee, 0.5));
      // Sanity in plain language: gaining weight while eating 3000
      // kcal/day means real TDEE must be below 3000 — some of that
      // intake is being stored, not burned.
      expect(tdeeValue, lessThan(dailyIntakeKcal));

      // Stage 4: macros, feeding the *actual* pipeline TDEE (not the
      // hand-derived one) through a 15% weight-loss deficit — the way a
      // real caller would chain these.
      final totalKcalGoal = tdeeValue * 0.85;
      final macros = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: totalKcalGoal,
        weightKg: stepWeight,
        heightCm: heightCm,
        proteinGPerKg: proteinGPerKg,
        isWeightLossGoal: true,
      );

      final reconstructedKcal =
          macros.proteinG * 4 + macros.fatG * 9 + macros.carbG * 4;
      expect(reconstructedKcal, closeTo(totalKcalGoal, 0.01));
      expect(
        macros.proteinG,
        closeTo((proteinGPerKg + 0.1) * stepWeight, 0.001),
      );

      // Stage 5: Dynamic Maintenance. A goal of 78kg is well outside the
      // 0.7kg band from the ~83.9kg final trend, so this should
      // recommend a deficit below the raw TDEE (pulling back toward
      // goal).
      final finalTrendWeight = trend.last.trendWeightKg;
      final maintenanceRecommendation = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: finalTrendWeight,
        goalWeightKg: 78.0,
        tdeeKcal: tdeeValue,
      );
      expect(maintenanceRecommendation, lessThan(tdeeValue));
    });

    test('realistic month: gaps, a one-day water-weight spike, and a real '
        'decline — sanity/directional checks rather than exact numbers, '
        'since this shape has no closed form', () {
      // True underlying weight is a perfectly linear decline from 85.0kg
      // (Jan 1) to 82.0kg (Jan 30) — a plausible ~0.7kg/week loss. Days
      // 5-6, 12-14, and 20 are missing (real people don't weigh in
      // daily), and day 10 has a one-day water-weight-style spike of
      // +1.5kg over the true line — the same kind of messy data a real
      // user produces, exercising interpolation and trend damping
      // together instead of in isolation.
      const startWeight = 85.0;
      const endWeight = 82.0;
      const totalDays = 30;
      const slopePerDay = (endWeight - startWeight) / (totalDays - 1);
      const goalWeightKg = 78.0;
      const heightCm = 178.0;
      const dailyIntakeKcal = 2200.0;

      double idealWeightAtDay(int dayIndex) =>
          startWeight + slopePerDay * dayIndex;

      final gapDays = {5, 6, 12, 13, 14, 20};
      final rawEntries = <WeightLogEntity>[];
      final intake = <DateTime, double>{};
      for (var dayIndex = 0; dayIndex < totalDays; dayIndex++) {
        final date = DateTime(2026, 1, 1 + dayIndex);
        intake[date] = dailyIntakeKcal;
        final dayNumber = dayIndex + 1;
        if (gapDays.contains(dayNumber)) continue;

        final weight = dayNumber == 10
            ? idealWeightAtDay(dayIndex) +
                  1.5 // the spike
            : idealWeightAtDay(dayIndex);
        rawEntries.add(entry(date, weight));
      }

      expect(rawEntries, hasLength(totalDays - gapDays.length));

      final filled = WeightInterpolationCalc.fillGaps(rawEntries);
      // Gaps are filled, so the dense series covers every day again.
      expect(filled, hasLength(totalDays));
      expect(filled.where((p) => p.isInterpolated), hasLength(gapDays.length));

      // Every gap sits between two real points that are both exactly on
      // the ideal line (the spike at day 10 never borders a gap), so
      // linear interpolation must reconstruct the ideal line exactly.
      for (final gapDay in gapDays) {
        final point = filled.firstWhere(
          (p) => p.date == DateTime(2026, 1, gapDay),
        );
        expect(
          point.weightKg,
          closeTo(idealWeightAtDay(gapDay - 1), 0.001),
          reason: 'gap day $gapDay should reconstruct the ideal line',
        );
      }

      final trend = WeightTrendCalc.computeTrend(filled);

      // The spike is damped, not fully reflected: day 10's trend should
      // stay well clear of the full +1.5kg raw spike, while still
      // nudging toward it a little — EWMA is a smoother, not a
      // rejecter.
      final spikePoint = filled.firstWhere(
        (p) => p.date == DateTime(2026, 1, 10),
      );
      final spikeTrendPoint = trend.firstWhere(
        (p) => p.date == DateTime(2026, 1, 10),
      );
      expect(spikeTrendPoint.trendWeightKg, lessThan(spikePoint.weightKg));
      expect(
        spikeTrendPoint.trendWeightKg,
        lessThan(idealWeightAtDay(9) + 1.3), // nowhere near the full spike
      );

      // Trend must reflect the overall decline: last day meaningfully
      // lower than first day, and within a generous band of the true
      // 82.0kg endpoint (EWMA lags a ramp by a small, bounded amount —
      // see the golden-path test above for the exact lag math on this
      // same slope).
      expect(trend.last.trendWeightKg, lessThan(trend.first.trendWeightKg));
      expect(trend.last.trendWeightKg, closeTo(endWeight, 2.0));

      final rate = TdeeDynamicCalc.weeklyChangeRateKg(trend);
      expect(rate, isNotNull);
      expect(rate!, lessThan(0)); // losing weight -> negative rate
      expect(rate, greaterThan(-2.0)); // not implausibly fast

      final tdee = TdeeDynamicCalc.estimateTdee(
        trendSeries: trend,
        dailyIntakeKcal: intake,
      );
      expect(tdee, isNotNull);
      final tdeeValue = tdee!;
      // Losing weight on a flat 2200 kcal/day means real TDEE is above
      // that flat intake (some of what's "eaten" is a deficit, not
      // storage) — the mirror image of the golden-path weight-gain
      // check.
      expect(tdeeValue, greaterThan(dailyIntakeKcal));
      expect(tdeeValue, lessThan(dailyIntakeKcal + 1500)); // not absurd

      final maintenanceRecommendation = DynamicMaintenanceCalc.recommendedKcal(
        trendWeightKg: trend.last.trendWeightKg,
        goalWeightKg: goalWeightKg,
        tdeeKcal: tdeeValue,
      );
      // Trend (~82-84kg) is still above the 78kg goal by more than the
      // 0.7kg band, so this should keep recommending a deficit.
      expect(maintenanceRecommendation, lessThan(tdeeValue));

      // Macros should still reconstruct exactly even when fed a
      // pipeline-derived (not hand-picked) calorie goal.
      final macros = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: maintenanceRecommendation,
        weightKg: trend.last.trendWeightKg,
        heightCm: heightCm,
        proteinGPerKg: 1.8,
        isWeightLossGoal: true,
      );
      final reconstructedKcal =
          macros.proteinG * 4 + macros.fatG * 9 + macros.carbG * 4;
      expect(reconstructedKcal, closeTo(maintenanceRecommendation, 0.01));
    });
  });
}
