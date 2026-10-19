import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

/// A single point in a gap-filled daily weight series: either a real
/// logged entry or a value linearly interpolated between two real entries.
typedef InterpolatedWeightPoint = ({
  DateTime date,
  double weightKg,
  bool isInterpolated,
});

class WeightInterpolationCalc {
  /// Fills gaps in [entries] with linearly interpolated values so that
  /// every calendar day between the earliest and latest entry has a
  /// point. MacroFactor documents this exact approach for its own trend
  /// calculation — linear interpolation over missing weigh-ins, ~1%
  /// accuracy — and Fase Motor's trend weight EWMA (see
  /// weight_trend_calc.dart) is designed to run on this gap-filled series
  /// rather than the raw sparse log.
  ///
  /// Days before the first entry or after the last entry are never
  /// synthesized: interpolation only fills *between* two known points, it
  /// never extrapolates beyond them. An empty or single-entry [entries]
  /// list is returned unchanged (a single point can't bracket a gap).
  ///
  /// [entries] is deduplicated to one point per calendar day (later
  /// duplicates win) and sorted ascending by date before processing. This
  /// mirrors WeightLogDataSource's own one-entry-per-day storage guarantee
  /// — entries pulled straight from the repository never have same-day
  /// duplicates in practice — but the method stays correct if ever fed
  /// raw/unsorted input.
  static List<InterpolatedWeightPoint> fillGaps(List<WeightLogEntity> entries) {
    if (entries.length < 2) {
      return entries
          .map(
            (e) => (
              date: _atMidnight(e.date),
              weightKg: e.weightKg,
              isInterpolated: false,
            ),
          )
          .toList();
    }

    final byDay = <DateTime, double>{};
    for (final entry in entries) {
      byDay[_atMidnight(entry.date)] = entry.weightKg;
    }
    final sortedDays = byDay.keys.toList()..sort();

    final result = <InterpolatedWeightPoint>[];
    for (var i = 0; i < sortedDays.length - 1; i++) {
      final startDay = sortedDays[i];
      final endDay = sortedDays[i + 1];
      final startWeight = byDay[startDay]!;
      final endWeight = byDay[endDay]!;

      result.add((
        date: startDay,
        weightKg: startWeight,
        isInterpolated: false,
      ));

      final gapDays = CalendarDayCalc.daysBetween(startDay, endDay);
      for (var d = 1; d < gapDays; d++) {
        final t = d / gapDays;
        result.add((
          date: CalendarDayCalc.addDays(startDay, d),
          weightKg: startWeight + (endWeight - startWeight) * t,
          isInterpolated: true,
        ));
      }
    }

    // The loop above only emits the *start* of each consecutive pair, so
    // the final real entry needs adding explicitly.
    final lastDay = sortedDays.last;
    result.add((
      date: lastDay,
      weightKg: byDay[lastDay]!,
      isInterpolated: false,
    ));

    return result;
  }

  static DateTime _atMidnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
