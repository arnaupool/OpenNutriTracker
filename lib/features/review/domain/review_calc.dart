import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';

/// How far back the review screen looks.
enum ReviewRange {
  days7(7),
  days30(30),
  days90(90),
  year(365),
  all(null);

  final int? days;

  const ReviewRange(this.days);

  /// First day of the range ending on [today]; null means no lower bound.
  DateTime? startFor(DateTime today) => days == null ? null : CalendarDayCalc.addDays(_day(today), -(days! - 1));
}

enum AdherencePeriod { day, week, month }

class ReviewWeightRow {
  final DateTime day;

  /// The scale reading that day; null on days without a weigh-in, where
  /// the trend is carried by interpolation.
  final double? scaleKg;
  final double trendKg;

  /// Trend change over the previous 7 days; null near the start.
  final double? weekChangeKg;

  const ReviewWeightRow(this.day, this.scaleKg, this.trendKg, this.weekChangeKg);
}

class ReviewExpenditureRow {
  final DateTime day;
  final double? intakeKcal;
  final double? goalKcal;

  /// Smoothed TDEE estimate as of that day, from the weight trend and the
  /// intake logged up to it; null until there is enough data.
  final double? expenditureKcal;

  const ReviewExpenditureRow(this.day, this.intakeKcal, this.goalKcal, this.expenditureKcal);
}

class ReviewAdherenceRow {
  final DateTime start;
  final int loggedDays;
  final double kcal;
  final double kcalGoal;
  final double protein;
  final double? proteinGoal;
  final double carbs;
  final double? carbsGoal;
  final double fat;
  final double? fatGoal;

  const ReviewAdherenceRow({
    required this.start,
    required this.loggedDays,
    required this.kcal,
    required this.kcalGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
  });

  /// Intake as a share of the goal (1.0 = on target).
  double? get kcalRatio => kcalGoal > 0 ? kcal / kcalGoal : null;
}

/// Turns the stored logs into the rows of the review screen (FAS-03).
/// Pure functions, so the numbers can be tested and exported as shown.
class ReviewCalc {
  static List<ReviewWeightRow> weight(List<WeightLogEntity> entries, {DateTime? from, required DateTime to}) {
    if (entries.isEmpty) return [];
    final scale = {for (final e in entries) _day(e.date): e.weightKg};
    final trend = WeightTrendCalc.computeTrend(WeightInterpolationCalc.fillGaps(entries));
    final trendByDay = {for (final p in trend) _day(p.date): p.trendWeightKg};
    return [
      for (final p in trend)
        if (_inRange(p.date, from, to))
          ReviewWeightRow(
            _day(p.date),
            scale[_day(p.date)],
            p.trendWeightKg,
            switch (trendByDay[CalendarDayCalc.addDays(_day(p.date), -7)]) {
              final double before => p.trendWeightKg - before,
              _ => null,
            },
          ),
    ];
  }

  /// One row per tracked day in range, with the expenditure estimate as it
  /// stood that day. The estimate is the same smoothed energy-balance figure
  /// Strategy shows today, computed incrementally so a year takes one pass.
  static List<ReviewExpenditureRow> expenditure(
    List<WeightLogEntity> entries,
    List<TrackedDayEntity> trackedDays, {
    DateTime? from,
    required DateTime to,
  }) {
    final intake = {for (final d in trackedDays) _day(d.day): d.caloriesTracked};
    final goals = {for (final d in trackedDays) _day(d.day): d.calorieGoal};
    final trend = entries.isEmpty
        ? <WeightTrendPoint>[]
        : WeightTrendCalc.computeTrend(WeightInterpolationCalc.fillGaps(entries));

    final estimate = <DateTime, double>{};
    double? smoothed;
    for (var i = 1; i <= trend.length; i++) {
      final raw = TdeeDynamicCalc.estimateTdee(trendSeries: trend.sublist(0, i), dailyIntakeKcal: intake);
      if (raw != null) {
        smoothed = smoothed == null ? raw : smoothed + TdeeDynamicCalc.expenditureSmoothingAlpha * (raw - smoothed);
      }
      if (smoothed != null && i >= TdeeDynamicCalc.minTrendPointsForDynamic) {
        estimate[_day(trend[i - 1].date)] = smoothed;
      }
    }

    final days = {...intake.keys, ...estimate.keys}.where((d) => _inRange(d, from, to)).toList()..sort();
    return [for (final d in days) ReviewExpenditureRow(d, intake[d], goals[d], estimate[d])];
  }

  /// Averages over the days that have something logged, grouped by day,
  /// ISO week (Monday start) or calendar month. Days with nothing eaten are
  /// left out rather than counted as zero, matching how the expenditure
  /// estimate treats untracked days.
  static List<ReviewAdherenceRow> adherence(
    List<TrackedDayEntity> trackedDays,
    AdherencePeriod period, {
    DateTime? from,
    required DateTime to,
  }) {
    final groups = <DateTime, List<TrackedDayEntity>>{};
    for (final d in trackedDays) {
      if (d.caloriesTracked <= 0 || !_inRange(d.day, from, to)) continue;
      groups.putIfAbsent(_periodStart(d.day, period), () => []).add(d);
    }
    final starts = groups.keys.toList()..sort();
    return [
      for (final start in starts)
        () {
          final g = groups[start]!;
          double avg(double Function(TrackedDayEntity) f) => g.map(f).reduce((a, b) => a + b) / g.length;
          double? avgGoal(double? Function(TrackedDayEntity) f) {
            final values = g.map(f).whereType<double>().toList();
            return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
          }

          return ReviewAdherenceRow(
            start: start,
            loggedDays: g.length,
            kcal: avg((d) => d.caloriesTracked),
            kcalGoal: avg((d) => d.calorieGoal),
            protein: avg((d) => d.proteinTracked ?? 0),
            proteinGoal: avgGoal((d) => d.proteinGoal),
            carbs: avg((d) => d.carbsTracked ?? 0),
            carbsGoal: avgGoal((d) => d.carbsGoal),
            fat: avg((d) => d.fatTracked ?? 0),
            fatGoal: avgGoal((d) => d.fatGoal),
          );
        }(),
    ];
  }

  static DateTime _periodStart(DateTime date, AdherencePeriod period) {
    final day = _day(date);
    return switch (period) {
      AdherencePeriod.day => day,
      AdherencePeriod.week => CalendarDayCalc.addDays(day, -(day.weekday - DateTime.monday)),
      AdherencePeriod.month => DateTime(day.year, day.month),
    };
  }

  static bool _inRange(DateTime date, DateTime? from, DateTime to) {
    final day = _day(date);
    return (from == null || !day.isBefore(_day(from))) && !day.isAfter(_day(to));
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// RFC 4180 CSV, the format spreadsheets open without asking.
class ReviewCsv {
  static String encode(List<String> headers, List<List<Object?>> rows) {
    final buffer = StringBuffer()..writeln(headers.map(_cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  static String _cell(Object? value) {
    final text = switch (value) {
      null => '',
      DateTime d => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}',
      double v => v.toStringAsFixed(1),
      _ => value.toString(),
    };
    if (text.contains(RegExp(r'[",\n\r]'))) return '"${text.replaceAll('"', '""')}"';
    return text;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
