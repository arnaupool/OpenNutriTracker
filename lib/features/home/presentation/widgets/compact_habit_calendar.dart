import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// A single-month rendition of the `table_calendar` +
/// `calendarBuilders.markerBuilder` pattern `DiaryTableCalendar` already
/// uses, shrunk (smaller row height) for the Home habits card rather than
/// Diary's full month view. Each day carries up to two markers: a filled
/// dot when food was logged and a ring when a weigh-in was recorded (shape
/// and color both differ, so the two read apart without relying on color).
/// Swiping/chevron navigation stays on: [onMonthChanged] fires whenever the
/// visible month changes so the owning card can refetch the marked days.
class CompactHabitCalendar extends StatelessWidget {
  final Set<DateTime> loggedDays;
  final Set<DateTime> weighedDays;
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;
  final ValueChanged<DateTime>? onMonthChanged;

  const CompactHabitCalendar({
    super.key,
    required this.loggedDays,
    required this.weighedDays,
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
    this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TableCalendar(
      focusedDay: focusedDay,
      firstDay: firstDay,
      lastDay: lastDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      onPageChanged: onMonthChanged,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        headerPadding: EdgeInsets.symmetric(vertical: 4.0),
      ),
      daysOfWeekHeight: 16.0,
      rowHeight: 32.0,
      calendarStyle: CalendarStyle(
        markersMaxCount: 2,
        outsideDaysVisible: false,
        defaultTextStyle: theme.textTheme.bodySmall ?? const TextStyle(),
        weekendTextStyle: theme.textTheme.bodySmall ?? const TextStyle(),
        todayTextStyle: theme.textTheme.bodySmall ?? const TextStyle(),
        todayDecoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.onSurface, width: 1.5),
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final atMidnight = DateTime(date.year, date.month, date.day);
          final logged = loggedDays.contains(atMidnight);
          final weighed = weighedDays.contains(atMidnight);
          if (!logged && !weighed) return const SizedBox();
          return Container(
            margin: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logged) HabitMarker.logging(theme),
                if (logged && weighed) const SizedBox(width: 2),
                if (weighed) HabitMarker.weighIn(theme),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The two marks of the habits calendar, shared with its legend.
class HabitMarker extends StatelessWidget {
  static const double size = 6.0;

  final bool ring;
  final Color color;

  /// Filled dot: food was logged.
  HabitMarker.logging(ThemeData theme, {super.key}) : ring = false, color = theme.colorScheme.primary;

  /// Ring: a weigh-in was recorded.
  HabitMarker.weighIn(ThemeData theme, {super.key}) : ring = true, color = theme.colorScheme.tertiary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? null : color,
        border: ring ? Border.all(color: color, width: 1.5) : null,
      ),
    );
  }
}
