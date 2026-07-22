import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// A single-month, non-interactive rendition of the `table_calendar` +
/// `calendarBuilders.markerBuilder` pattern `DiaryTableCalendar` already
/// uses — but shrunk (no header nav, smaller row height) and dumbed down
/// to plain day-is-marked-or-not, for compact Home habit widgets (FD-09,
/// FD-10) rather than Diary's full interactive month view.
class CompactHabitCalendar extends StatelessWidget {
  final Set<DateTime> markedDays;
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;

  const CompactHabitCalendar({
    super.key,
    required this.markedDays,
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TableCalendar(
      focusedDay: focusedDay,
      firstDay: firstDay,
      lastDay: lastDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.none,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        leftChevronVisible: false,
        rightChevronVisible: false,
        headerPadding: EdgeInsets.symmetric(vertical: 4.0),
      ),
      daysOfWeekHeight: 16.0,
      rowHeight: 32.0,
      calendarStyle: CalendarStyle(
        markersMaxCount: 1,
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
          if (!markedDays.contains(atMidnight)) return const SizedBox();
          return Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
            width: 5.0,
            height: 5.0,
          );
        },
      ),
    );
  }
}
