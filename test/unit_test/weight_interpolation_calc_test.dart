import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';

void main() {
  WeightLogEntity entry(DateTime date, double weightKg) {
    return WeightLogEntity(date: date, weightKg: weightKg);
  }

  test('empty list returns empty', () {
    final result = WeightInterpolationCalc.fillGaps([]);
    expect(result, isEmpty);
  });

  test('single entry is returned unchanged, not interpolated', () {
    final date = DateTime(2026, 1, 1);
    final result = WeightInterpolationCalc.fillGaps([entry(date, 80.0)]);

    expect(result, hasLength(1));
    expect(result.single.date, date);
    expect(result.single.weightKg, 80.0);
    expect(result.single.isInterpolated, isFalse);
  });

  test('two consecutive days produce no interpolated points', () {
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 1), 80.0),
      entry(DateTime(2026, 1, 2), 79.6),
    ]);

    expect(result, hasLength(2));
    expect(result.every((p) => !p.isInterpolated), isTrue);
  });

  test('linearly interpolates a single gap', () {
    // 4-day gap: day 0 = 80kg, day 4 = 76kg -> 1kg/day steps in between.
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 1), 80.0),
      entry(DateTime(2026, 1, 5), 76.0),
    ]);

    expect(result, hasLength(5));
    expect(result[0].date, DateTime(2026, 1, 1));
    expect(result[0].weightKg, 80.0);
    expect(result[0].isInterpolated, isFalse);

    expect(result[1].date, DateTime(2026, 1, 2));
    expect(result[1].weightKg, closeTo(79.0, 0.001));
    expect(result[1].isInterpolated, isTrue);

    expect(result[2].date, DateTime(2026, 1, 3));
    expect(result[2].weightKg, closeTo(78.0, 0.001));
    expect(result[2].isInterpolated, isTrue);

    expect(result[3].date, DateTime(2026, 1, 4));
    expect(result[3].weightKg, closeTo(77.0, 0.001));
    expect(result[3].isInterpolated, isTrue);

    expect(result[4].date, DateTime(2026, 1, 5));
    expect(result[4].weightKg, 76.0);
    expect(result[4].isInterpolated, isFalse);
  });

  test('never extrapolates before the first or after the last entry', () {
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 1), 80.0),
      entry(DateTime(2026, 1, 3), 79.0),
    ]);

    // Only Jan 1-3, nothing before or after.
    expect(result.first.date, DateTime(2026, 1, 1));
    expect(result.last.date, DateTime(2026, 1, 3));
    expect(result, hasLength(3));
  });

  test('walks multiple segments with different gap sizes without '
      'duplicating boundary days', () {
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 1), 80.0),
      entry(DateTime(2026, 1, 3), 78.0), // 2-day gap
      entry(DateTime(2026, 1, 4), 78.5), // no gap
      entry(DateTime(2026, 1, 7), 77.0), // 3-day gap
    ]);

    final dates = result.map((p) => p.date).toList();
    expect(dates, [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 4),
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 6),
      DateTime(2026, 1, 7),
    ]);

    final byDate = {for (final p in result) p.date: p};
    expect(byDate[DateTime(2026, 1, 2)]!.isInterpolated, isTrue);
    expect(byDate[DateTime(2026, 1, 2)]!.weightKg, closeTo(79.0, 0.001));
    expect(byDate[DateTime(2026, 1, 3)]!.isInterpolated, isFalse);
    expect(byDate[DateTime(2026, 1, 4)]!.isInterpolated, isFalse);
    expect(byDate[DateTime(2026, 1, 5)]!.isInterpolated, isTrue);
    expect(byDate[DateTime(2026, 1, 6)]!.isInterpolated, isTrue);
    expect(byDate[DateTime(2026, 1, 7)]!.isInterpolated, isFalse);
  });

  test('same-day duplicate entries: the later one in the input list wins', () {
    final date = DateTime(2026, 1, 1);
    final result = WeightInterpolationCalc.fillGaps([
      entry(date, 80.0),
      entry(date, 81.0),
      entry(DateTime(2026, 1, 2), 79.0),
    ]);

    final firstDay = result.firstWhere((p) => p.date == date);
    expect(firstDay.weightKg, 81.0);
  });

  test('processes unsorted input correctly', () {
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 5), 76.0),
      entry(DateTime(2026, 1, 1), 80.0),
    ]);

    expect(result.first.date, DateTime(2026, 1, 1));
    expect(result.last.date, DateTime(2026, 1, 5));
    expect(result, hasLength(5));
  });

  test('ignores the time-of-day component and keys purely by calendar day', () {
    final result = WeightInterpolationCalc.fillGaps([
      entry(DateTime(2026, 1, 1, 7, 30), 80.0),
      entry(DateTime(2026, 1, 3, 22, 0), 78.0),
    ]);

    expect(result.first.date, DateTime(2026, 1, 1));
    expect(result.last.date, DateTime(2026, 1, 3));
    expect(result, hasLength(3));
  });
}
