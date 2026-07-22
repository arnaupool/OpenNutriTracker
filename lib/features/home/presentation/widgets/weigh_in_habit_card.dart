import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/widgets/compact_habit_calendar.dart';
import 'package:opennutritracker/generated/l10n.dart';

class WeighInHabitCard extends StatefulWidget {
  final GetWeightLogUsecase? getWeightLogUsecase;

  const WeighInHabitCard({super.key, this.getWeightLogUsecase});

  @override
  State<WeighInHabitCard> createState() => _WeighInHabitCardState();
}

class _WeighInHabitCardState extends State<WeighInHabitCard> {
  // Matches DiaryTableCalendar's own navigable range (±5 years from today)
  // so this card's calendar isn't locked to the current month.
  static const _navigableRange = Duration(days: 365 * 5);

  late final GetWeightLogUsecase _weightUsecase =
      widget.getWeightLogUsecase ?? locator<GetWeightLogUsecase>();

  bool _loading = true;
  Set<DateTime> _markedDays = const {};
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
    final entries = await _weightUsecase.getEntriesInRange(
      monthStart,
      monthEnd,
    );
    final markedDays = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();

    if (!mounted) return;
    setState(() {
      _focusedDay = focusedDay;
      _markedDays = markedDays;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = S.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.homeWeighInHabitCardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Semantics(
              identifier: 'home-weigh-in-habit-calendar',
              child: CompactHabitCalendar(
                markedDays: _markedDays,
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                onMonthChanged: _loadMonth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
