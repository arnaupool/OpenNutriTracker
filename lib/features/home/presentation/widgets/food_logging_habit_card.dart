import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/widgets/compact_habit_calendar.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Days with only an activity logged also produce a `TrackedDayDBO`
/// (`addNewTrackedDay` is called from both the meal and activity flows),
/// so a raw tracked-day range would count activity-only days as a
/// logging streak. Filtering on `caloriesTracked > 0` isolates days with
/// real food intake — the only new logic this card adds on top of the
/// existing `GetTrackedDayUsecase.getTrackedDaysByRange`.
class FoodLoggingHabitCard extends StatefulWidget {
  final GetTrackedDayUsecase? getTrackedDayUsecase;

  const FoodLoggingHabitCard({super.key, this.getTrackedDayUsecase});

  @override
  State<FoodLoggingHabitCard> createState() => _FoodLoggingHabitCardState();
}

class _FoodLoggingHabitCardState extends State<FoodLoggingHabitCard> {
  late final GetTrackedDayUsecase _trackedDayUsecase =
      widget.getTrackedDayUsecase ?? locator<GetTrackedDayUsecase>();

  bool _loading = true;
  Set<DateTime> _markedDays = const {};
  late DateTime _now;
  late DateTime _monthStart;
  late DateTime _monthEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final trackedDays = await _trackedDayUsecase.getTrackedDaysByRange(
      monthStart,
      monthEnd,
    );
    final markedDays = trackedDays
        .where((d) => d.caloriesTracked > 0)
        .map((d) => DateTime(d.day.year, d.day.month, d.day.day))
        .toSet();

    if (!mounted) return;
    setState(() {
      _now = now;
      _monthStart = monthStart;
      _monthEnd = monthEnd;
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
              s.homeLoggingHabitCardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Semantics(
              identifier: 'home-logging-habit-calendar',
              child: CompactHabitCalendar(
                markedDays: _markedDays,
                firstDay: _monthStart,
                lastDay: _monthEnd,
                focusedDay: _now,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
