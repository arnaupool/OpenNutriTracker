import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/daily_nutrient_panel.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FD-03: the calendar-week bar-chart overview (calories, fat, protein,
/// sodium) that sits above the day summary — one mini [BarChart] per
/// nutrient, a dashed [HorizontalLine] marking the selected day's goal, and
/// the selected day's own bar drawn brighter than the rest of the week.
///
/// Calories/fat/protein come straight off [TrackedDayEntity] (already
/// aggregated per day when intake is logged). Sodium has no such field —
/// [MealNutrimentsDBO] only carries it per-100g — so it's summed from the
/// day's intake list the same way [DailyNutrientPanel]'s weekly average
/// does, just bucketed per day instead of merged across the week.
class WeeklyNutrientBars extends StatefulWidget {
  final DateTime selectedDate;
  final GetTrackedDayUsecase? getTrackedDayUsecase;
  final GetIntakeUsecase? getIntakeUsecase;

  const WeeklyNutrientBars({
    super.key,
    required this.selectedDate,
    this.getTrackedDayUsecase,
    this.getIntakeUsecase,
  });

  @override
  State<WeeklyNutrientBars> createState() => _WeeklyNutrientBarsState();
}

class _WeeklyNutrientBarsState extends State<WeeklyNutrientBars> {
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();
  late final GetIntakeUsecase _intakeUsecase =
      widget.getIntakeUsecase ?? locator<GetIntakeUsecase>();

  Future<_WeekData>? _weekDataFuture;
  DateTime? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeReload();
  }

  @override
  void didUpdateWidget(covariant WeeklyNutrientBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeReload();
  }

  void _maybeReload() {
    final weekStart = _weekStart(widget.selectedDate);
    if (_loadedFor == weekStart) return;
    _loadedFor = weekStart;
    _weekDataFuture = _loadWeek(weekStart);
  }

  static DateTime _weekStart(DateTime date) {
    final midnight = DateTime(date.year, date.month, date.day);
    return midnight.subtract(Duration(days: midnight.weekday - 1));
  }

  Future<_WeekData> _loadWeek(DateTime weekStart) async {
    // TrackedDayDBO.day isn't always normalized to midnight (some write
    // paths persist the raw DateTime.now() the entry was first created
    // with), so an end-of-range bound of "Sunday at 00:00" would silently
    // drop today's entry whenever it carries a real time-of-day. Push the
    // bound to the last instant of Sunday instead.
    final weekEnd = weekStart
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(
      weekStart,
      weekEnd,
    );
    final trackedByDay = {
      for (final t in trackedDays)
        DateTime(t.day.year, t.day.month, t.day.day): t,
    };

    final sodiumByDay = <DateTime, double>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayIntakes = [
        ...await _intakeUsecase.getBreakfastIntakeByDay(day),
        ...await _intakeUsecase.getLunchIntakeByDay(day),
        ...await _intakeUsecase.getDinnerIntakeByDay(day),
        ...await _intakeUsecase.getSnackIntakeByDay(day),
      ];
      sodiumByDay[day] = NutrientPanelTotals.fromIntakes(dayIntakes).sodiumMg;
    }

    return _WeekData(trackedByDay: trackedByDay, sodiumByDay: sodiumByDay);
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _weekStart(widget.selectedDate);
    final selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];

    return FutureBuilder<_WeekData>(
      future: _weekDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final trackedByDay = data?.trackedByDay ?? const {};
        final sodiumByDay = data?.sodiumByDay ?? const {};
        final selectedTracked = trackedByDay[selectedDay];
        final s = S.of(context);
        final theme = Theme.of(context);

        return Semantics(
          identifier: 'diary-weekly-nutrient-bars',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.diaryWeeklyBarsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _MiniBarChart(
                    label: s.caloriesLabel,
                    unit: s.kcalLabel,
                    days: days,
                    selectedDay: selectedDay,
                    values: [
                      for (final d in days)
                        trackedByDay[d]?.caloriesTracked ?? 0,
                    ],
                    goal: selectedTracked?.calorieGoal,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _MiniBarChart(
                    label: s.fatLabel,
                    unit: 'g',
                    days: days,
                    selectedDay: selectedDay,
                    values: [
                      for (final d in days) trackedByDay[d]?.fatTracked ?? 0,
                    ],
                    goal: selectedTracked?.fatGoal,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 16),
                  _MiniBarChart(
                    label: s.proteinLabel,
                    unit: 'g',
                    days: days,
                    selectedDay: selectedDay,
                    values: [
                      for (final d in days)
                        trackedByDay[d]?.proteinTracked ?? 0,
                    ],
                    goal: selectedTracked?.proteinGoal,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  _MiniBarChart(
                    label: s.sodiumLabel,
                    unit: 'mg',
                    days: days,
                    selectedDay: selectedDay,
                    values: [for (final d in days) sodiumByDay[d] ?? 0],
                    goal: DailyNutrientPanel.resolveSodiumReference(
                      selectedTracked,
                    ),
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekData {
  final Map<DateTime, TrackedDayEntity> trackedByDay;
  final Map<DateTime, double> sodiumByDay;

  const _WeekData({required this.trackedByDay, required this.sodiumByDay});
}

class _MiniBarChart extends StatelessWidget {
  static const double _chartHeight = 72;

  final String label;
  final String unit;
  final List<DateTime> days;
  final DateTime selectedDay;
  final List<double> values;
  final double? goal;
  final Color color;

  const _MiniBarChart({
    required this.label,
    required this.unit,
    required this.days,
    required this.selectedDay,
    required this.values,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayFormat = DateFormat('EEEEE', localeTag);
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = [maxValue, goal ?? 0].reduce((a, b) => a > b ? a : b) * 1.2;
    final safeMaxY = maxY <= 0 ? 1.0 : maxY;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${goal == null ? '' : ' (${goal!.round()} $unit)'}',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _chartHeight,
          child: BarChart(
            BarChartData(
              maxY: safeMaxY,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              extraLinesData: goal == null
                  ? const ExtraLinesData()
                  : ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: goal!,
                          color: theme.colorScheme.onSurfaceVariant,
                          strokeWidth: 1,
                          dashArray: const [4, 3],
                        ),
                      ],
                    ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 16,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= days.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          dayFormat.format(days[index]),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: DateUtils.isSameDay(days[i], selectedDay)
                            ? color
                            : color.withValues(alpha: 0.35),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
