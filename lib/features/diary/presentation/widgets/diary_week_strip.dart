import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Phone-width replacement for the month calendar at the top of the Diary:
/// seven day cells (Monday to Sunday) for the week of [selectedDate], a
/// header with month and year that opens a date picker, and previous / next
/// week buttons (also reachable by a horizontal swipe).
///
/// The widget is fully controlled: the visible week is always the week of
/// [selectedDate]. Every navigation (day tap, week buttons, swipe, picker)
/// reports through [onDateSelected], so the parent loads the diary of the new
/// day exactly like a tap in the month calendar does.
class DiaryWeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime currentDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Map<String, TrackedDayEntity> trackedDaysMap;
  final Function(DateTime, Map<String, TrackedDayEntity>) onDateSelected;

  const DiaryWeekStrip({
    super.key,
    required this.selectedDate,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.trackedDaysMap,
    required this.onDateSelected,
  });

  /// Monday of the week containing [date], at midnight.
  static DateTime weekStartOf(DateTime date) {
    final midnight = DateTime(date.year, date.month, date.day);
    return DateTime(midnight.year, midnight.month, midnight.day - (midnight.weekday - 1));
  }

  void _select(DateTime date) => onDateSelected(date, trackedDaysMap);

  void _shiftWeek(int weeks) {
    _select(DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 7 * weeks));
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) _select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monthFormat = DateFormat.yMMMM(localeTag);
    final weekdayFormat = DateFormat('EEEEE', localeTag);
    final weekStart = weekStartOf(selectedDate);
    final days = [for (var i = 0; i < 7; i++) DateTime(weekStart.year, weekStart.month, weekStart.day + i)];
    final monthTitle = toBeginningOfSentenceCase(monthFormat.format(selectedDate), localeTag);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) {
          _shiftWeek(1);
        } else if (velocity > 300) {
          _shiftWeek(-1);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Semantics(
                  identifier: 'diary-week-prev',
                  child: IconButton(
                    tooltip: s.diaryWeekPrevious,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftWeek(-1),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    identifier: 'diary-week-month-picker',
                    child: Tooltip(
                      message: s.diaryWeekPickDate,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickDate(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  monthTitle,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'diary-week-next',
                  child: IconButton(
                    tooltip: s.diaryWeekNext,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shiftWeek(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: _DayCell(
                      day: day,
                      label: weekdayFormat.format(day),
                      isSelected: DateUtils.isSameDay(day, selectedDate),
                      isToday: DateUtils.isSameDay(day, currentDate),
                      trackedDay: trackedDaysMap[day.toParsedDay()],
                      onTap: () => _select(day),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final String label;
  final bool isSelected;
  final bool isToday;
  final TrackedDayEntity? trackedDay;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.trackedDay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final numberStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isSelected ? scheme.onPrimary : scheme.onSurface,
      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
    );

    return Semantics(
      identifier: 'diary-week-day',
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Container(
                key: ValueKey('diary-week-day-${day.toParsedDay()}${isSelected ? '-selected' : ''}'),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? scheme.primary : null,
                  border: isToday ? Border.all(color: scheme.onSurface, width: 2.0) : null,
                ),
                child: Text('${day.day}', style: numberStyle),
              ),
              const SizedBox(height: 4),
              // Same per-day rating dot the month calendar shows.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trackedDay?.getCalendarDayRatingColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
