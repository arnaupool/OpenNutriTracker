import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/features/review/domain/review_calc.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 10, day);

  TrackedDayEntity tracked(int day, double kcal, {double goal = 2000, double protein = 100}) => TrackedDayEntity(
    day: d(day),
    calorieGoal: goal,
    caloriesTracked: kcal,
    proteinGoal: 120,
    proteinTracked: protein,
    carbsGoal: 250,
    carbsTracked: 200,
    fatGoal: 70,
    fatTracked: 60,
  );

  group('weight', () {
    test('marks scale readings, fills the trend between them and reports weekly change', () {
      final rows = ReviewCalc.weight([
        WeightLogEntity(date: d(1), weightKg: 80),
        WeightLogEntity(date: d(9), weightKg: 79),
      ], to: d(9));
      expect(rows.length, 9);
      expect(rows.first.scaleKg, 80);
      expect(rows[3].scaleKg, isNull, reason: 'no weigh-in on the 4th');
      expect(rows.last.scaleKg, 79);
      expect(rows.first.weekChangeKg, isNull);
      expect(rows.last.weekChangeKg, isNotNull);
      expect(rows.last.weekChangeKg!, lessThan(0));
    });

    test('respects the range', () {
      final rows = ReviewCalc.weight([
        WeightLogEntity(date: d(1), weightKg: 80),
        WeightLogEntity(date: d(20), weightKg: 79),
      ], from: d(10), to: d(12));
      expect(rows.map((r) => r.day), [d(10), d(11), d(12)]);
    });
  });

  group('expenditure', () {
    test('no estimate before enough trend points, then a plausible one', () {
      // Weight stable at 80 kg while eating 2500 kcal/day: TDEE ~2500.
      final weights = [for (var i = 1; i <= 21; i++) WeightLogEntity(date: d(i), weightKg: 80)];
      final days = [for (var i = 1; i <= 21; i++) tracked(i, 2500)];
      final rows = ReviewCalc.expenditure(weights, days, to: d(21));
      expect(rows.first.expenditureKcal, isNull);
      expect(rows[TdeeDynamicCalc.minTrendPointsForDynamic - 1].expenditureKcal, isNotNull);
      expect(rows.last.expenditureKcal, closeTo(2500, 1));
      expect(rows.last.intakeKcal, 2500);
      expect(rows.last.goalKcal, 2000);
    });
  });

  group('adherence', () {
    final days = [
      tracked(5, 1800), // Monday
      tracked(6, 2200),
      tracked(7, 0), // nothing logged: left out
      tracked(12, 2000), // next Monday
    ];

    test('weekly averages over logged days only', () {
      final rows = ReviewCalc.adherence(days, AdherencePeriod.week, to: d(31));
      expect(rows.length, 2);
      expect(rows.first.start, d(5));
      expect(rows.first.loggedDays, 2);
      expect(rows.first.kcal, 2000);
      expect(rows.first.kcalRatio, 1.0);
      expect(rows.last.start, d(12));
    });

    test('monthly and daily grouping', () {
      expect(ReviewCalc.adherence(days, AdherencePeriod.month, to: d(31)).single.loggedDays, 3);
      expect(ReviewCalc.adherence(days, AdherencePeriod.day, to: d(31)).length, 3);
    });
  });

  group('csv', () {
    test('formats dates and numbers, quotes when needed', () {
      final csv = ReviewCsv.encode(
        ['date', 'food', 'kcal'],
        [
          [d(5), 'Paella, valenciana', 512.345],
          [d(6), 'Say "hi"', null],
        ],
      );
      expect(csv.split('\n'), [
        'date,food,kcal',
        '2026-10-05,"Paella, valenciana",512.3',
        '2026-10-06,"Say ""hi""",',
        '',
      ]);
    });
  });

  test('ranges end today and include it', () {
    expect(ReviewRange.days7.startFor(DateTime(2026, 10, 23, 15)), d(17));
    expect(ReviewRange.all.startFor(d(23)), isNull);
  });
}
