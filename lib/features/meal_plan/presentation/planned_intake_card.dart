import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/meal_plan/domain/log_meal_plan_usecase.dart';
import 'package:opennutritracker/features/meal_plan/domain/meal_plan_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Rebuilds [builder] with the entries of the meal plan still pending for
/// [day] and [type], whenever the plan changes (the plan screen, a synced
/// edit, a confirmation). Planned entries are not intakes: they count in no
/// total until confirmed.
class PlannedEntriesBuilder extends StatelessWidget {
  final DateTime day;
  final IntakeTypeEntity type;
  final Widget Function(BuildContext context, List<Widget> plannedCards) builder;

  /// Tests inject their own; the app uses the registered one.
  final LogMealPlanUsecase? usecase;

  const PlannedEntriesBuilder({super.key, required this.day, required this.type, required this.builder, this.usecase});

  @override
  Widget build(BuildContext context) {
    final plan = usecase ?? (locator.isRegistered<LogMealPlanUsecase>() ? locator<LogMealPlanUsecase>() : null);
    if (plan == null) return builder(context, const []);
    return ListenableBuilder(
      listenable: plan.listenable(),
      builder: (context, _) {
        final entries = plan.pendingFor(day).where((e) => e.type.name == type.name).toList();
        return builder(context, [
          for (final e in entries) PlannedIntakeCard(key: ValueKey('planned-${e.id}'), entry: e, usecase: plan),
        ]);
      },
    );
  }
}

/// A planned item shown in its meal of the Diary: dimmed, labelled
/// "Planned", with one tap to confirm (logs it as a normal intake of that
/// day and meal) or discard (hides it for that day).
class PlannedIntakeCard extends StatefulWidget {
  final MealPlanEntryDBO entry;
  final LogMealPlanUsecase usecase;

  const PlannedIntakeCard({super.key, required this.entry, required this.usecase});

  @override
  State<PlannedIntakeCard> createState() => _PlannedIntakeCardState();
}

class _PlannedIntakeCardState extends State<PlannedIntakeCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    _refreshScreens();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final entry = widget.entry;
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return SizedBox(
      width: 168,
      height: 120,
      child: Card(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.planDiaryPlannedLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.8),
              ),
              Text(
                entry.meal.name ?? '?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(color: dim),
              ),
              Text(
                '${entry.amount.round()} ${entry.unit} · '
                '${EnergyDisplay.formatWithUnit(context, MealPlanCalc.totalsOf(entry).kcal)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: dim),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      identifier: 'diary-planned-confirm',
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: _busy ? null : () => _run(() => widget.usecase.confirm(entry.id)),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(s.planDiaryConfirm)),
                      ),
                    ),
                  ),
                  Semantics(
                    identifier: 'diary-planned-discard',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: s.planDiaryDiscard,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _busy ? null : () => _run(() => widget.usecase.discard(entry.id)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A confirmation adds an intake: reload what shows the day's totals.
  void _refreshScreens() {
    if (locator.isRegistered<HomeBloc>()) locator<HomeBloc>().add(const LoadItemsEvent());
    if (locator.isRegistered<DiaryBloc>()) locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    if (locator.isRegistered<CalendarDayBloc>()) locator<CalendarDayBloc>().add(const RefreshCalendarDayEvent());
  }
}
