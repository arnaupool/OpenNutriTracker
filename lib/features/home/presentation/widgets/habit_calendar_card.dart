import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/widgets/compact_habit_calendar.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// One month calendar for both habits: food logging (filled dot) and
/// weigh-ins (ring), a legend, and how many days of the visible month each
/// habit covers.
///
/// Days with only an activity logged also produce a `TrackedDayDBO`, so
/// logging days are the tracked days with `caloriesTracked > 0`. Days after
/// today count too: the owner logs ahead on purpose.
class HabitCalendarCard extends StatefulWidget {
  final GetTrackedDayUsecase? getTrackedDayUsecase;
  final GetWeightLogUsecase? getWeightLogUsecase;

  const HabitCalendarCard({super.key, this.getTrackedDayUsecase, this.getWeightLogUsecase});

  @override
  State<HabitCalendarCard> createState() => _HabitCalendarCardState();
}

class _HabitCalendarCardState extends State<HabitCalendarCard> {
  // Matches DiaryTableCalendar's own navigable range (+-5 years from today)
  // so the calendar isn't locked to the current month.
  static const _navigableRange = Duration(days: 365 * 5);

  late final GetTrackedDayUsecase _trackedDayUsecase = widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();
  late final GetWeightLogUsecase _weightUsecase = widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();

  bool _loading = true;
  Set<DateTime> _loggedDays = const {};
  Set<DateTime> _weighedDays = const {};
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _focusedDay = today;
    _firstDay = today.subtract(_navigableRange);
    _lastDay = today.add(_navigableRange);
    _loadMonth(today);
  }

  Future<void> _loadMonth(DateTime focusedDay) async {
    final monthStart = DateTime(focusedDay.year, focusedDay.month, 1);
    final monthEnd = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(monthStart, monthEnd);
    final weighIns = await _weightUsecase.getEntriesInRange(monthStart, monthEnd);
    final logged = trackedDays
        .where((d) => d.caloriesTracked > 0)
        .map((d) => DateTime(d.day.year, d.day.month, d.day.day))
        .toSet();
    final weighed = weighIns.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet();

    if (!mounted) return;
    setState(() {
      _focusedDay = focusedDay;
      _loggedDays = logged;
      _weighedDays = weighed;
      _loading = false;
    });
  }

  bool _inFocusedMonth(DateTime d) => d.year == _focusedDay.year && d.month == _focusedDay.month;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final loggedCount = _loggedDays.where(_inFocusedMonth).length;
    final weighedCount = _weighedDays.where(_inFocusedMonth).length;

    Widget legend(Widget marker, String label, int count) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6.0),
        Text('$label ${s.homeHabitDaysCount(count)}', style: theme.textTheme.bodySmall),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.homeHabitsCardTitle, style: theme.textTheme.titleMedium),
            Semantics(
              identifier: 'home-habit-calendar',
              child: CompactHabitCalendar(
                loggedDays: _loggedDays,
                weighedDays: _weighedDays,
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                onMonthChanged: _loadMonth,
              ),
            ),
            const SizedBox(height: 4.0),
            Semantics(
              identifier: 'home-habit-legend',
              container: true,
              child: Wrap(
                spacing: 16.0,
                runSpacing: 4.0,
                children: [
                  legend(HabitMarker.weighIn(theme), s.homeHabitWeighInLabel, weighedCount),
                  legend(HabitMarker.logging(theme), s.homeHabitLoggingLabel, loggedCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
