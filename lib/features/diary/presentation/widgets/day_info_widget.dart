import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/activity_vertial_list.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_or_delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/macro_nutriments_widget.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_day_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/custom_icons.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/daily_nutrient_panel.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_sort_type.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

class DayInfoWidget extends StatefulWidget {
  final DateTime selectedDay;
  final TrackedDayEntity? trackedDayEntity;
  final List<UserActivityEntity> userActivities;
  final List<IntakeEntity> breakfastIntake;
  final List<IntakeEntity> lunchIntake;
  final List<IntakeEntity> dinnerIntake;
  final List<IntakeEntity> snackIntake;
  // #150: per-meal recommended kcal targets for the selected calendar day.
  // 0 means no target should be shown for that section (e.g. days with no
  // tracked daily goal).
  final double breakfastKcalTarget;
  final double lunchKcalTarget;
  final double dinnerKcalTarget;
  final double snackKcalTarget;
  // #150 follow-up: per-meal share percentages. A 0% share hides the section
  // entirely — useful for OMAD / two-meal users who don't want an empty meal
  // slot they've explicitly opted out of staring back at them.
  final int breakfastSharePct;
  final int lunchSharePct;
  final int dinnerSharePct;
  final int snackSharePct;

  final bool usesImperialUnits;
  final bool showMealMacros;
  // When the user disables Show Activity Tracking in Settings, the diary's
  // per-day Activity section is hidden alongside the home one.
  final bool showActivityTracking;
  // Persisted per-meal sort preference loaded by [CalendarDayBloc]. Keys are
  // meal-type strings (breakfast / lunch / dinner / snack) and values are
  // [DiarySortType] enum indices. Null when the user has never picked a
  // sort, in which case every section starts on [DiarySortType.timeAdded].
  final Map<String, int>? diarySortPreferences;
  final Function(
    IntakeEntity intake,
    TrackedDayEntity? trackedDayEntity, {
    bool isMove,
  })
  onDeleteIntake;
  final Function(
    UserActivityEntity userActivityEntity,
    TrackedDayEntity? trackedDayEntity,
  ) onDeleteActivity;
  final Function(
    IntakeEntity intake,
    TrackedDayEntity? trackedDayEntity,
    AddMealType? type,
    DateTime targetDate,
  ) onCopyIntake;
  final Function(
    UserActivityEntity userActivityEntity,
    TrackedDayEntity? trackedDayEntity,
  ) onCopyActivity;
  final Function(BuildContext context, IntakeEntity intake, bool usesImperialUnits)?
      onEditIntake;
  final Function(BuildContext context, UserActivityEntity activity)?
      onEditActivity;

  const DayInfoWidget({
    super.key,
    required this.selectedDay,
    required this.trackedDayEntity,
    required this.userActivities,
    required this.breakfastIntake,
    required this.lunchIntake,
    required this.dinnerIntake,
    required this.snackIntake,
    required this.usesImperialUnits,
    this.showMealMacros = true,
    this.showActivityTracking = true,
    this.diarySortPreferences,
    required this.onDeleteIntake,
    required this.onDeleteActivity,
    required this.onCopyIntake,
    required this.onCopyActivity,
    this.onEditIntake,
    this.onEditActivity,
    this.breakfastKcalTarget = 0,
    this.lunchKcalTarget = 0,
    this.dinnerKcalTarget = 0,
    this.snackKcalTarget = 0,
    this.breakfastSharePct = 30,
    this.lunchSharePct = 40,
    this.dinnerSharePct = 20,
    this.snackSharePct = 10,
  });

  @override
  State<DayInfoWidget> createState() => _DayInfoWidgetState();
}

class _DayInfoWidgetState extends State<DayInfoWidget> {
  // Per-meal sort selection. Seeded from the persisted preferences on
  // [ConfigDBO] (via [CalendarDayBloc]) so the choice survives navigation
  // and app restart, and falls back to [DiarySortType.timeAdded] for any
  // meal type the user has not yet customised. We keep a local widget-state
  // copy so the picker updates optimistically without waiting for the next
  // calendar-day reload.
  late Map<IntakeTypeEntity, DiarySortType> _sortByMeal;

  @override
  void initState() {
    super.initState();
    _sortByMeal = _seedFromPreferences(widget.diarySortPreferences);
  }

  @override
  void didUpdateWidget(covariant DayInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the bloc emits an updated preference map (for example because the
    // user switched days and the freshly loaded config has a different
    // breakfast sort), reseed so the picker reflects what's persisted.
    if (oldWidget.diarySortPreferences != widget.diarySortPreferences) {
      _sortByMeal = _seedFromPreferences(widget.diarySortPreferences);
    }
  }

  Map<IntakeTypeEntity, DiarySortType> _seedFromPreferences(
    Map<String, int>? persisted,
  ) {
    Map<IntakeTypeEntity, DiarySortType> defaults() => {
          IntakeTypeEntity.breakfast: DiarySortType.timeAdded,
          IntakeTypeEntity.lunch: DiarySortType.timeAdded,
          IntakeTypeEntity.dinner: DiarySortType.timeAdded,
          IntakeTypeEntity.snack: DiarySortType.timeAdded,
        };

    if (persisted == null) return defaults();

    final seeded = defaults();
    for (final mealType in IntakeTypeEntity.values) {
      final storedIndex = persisted[mealType.name];
      if (storedIndex == null) continue;
      // Defensive bound check — if a future build ever removes a sort
      // option, an older index might land here. Falling back to the default
      // keeps the diary from crashing on stale data.
      if (storedIndex < 0 || storedIndex >= DiarySortType.values.length) {
        continue;
      }
      seeded[mealType] = DiarySortType.values[storedIndex];
    }
    return seeded;
  }

  void _setSortFor(IntakeTypeEntity mealType, DiarySortType sortType) {
    setState(() {
      _sortByMeal[mealType] = sortType;
    });
    // Persist asynchronously — we don't block the UI on the write. The
    // optimistic widget-state update above means the picker reflects the
    // user's choice immediately even if the disk write is still in flight.
    locator<CalendarDayBloc>()
        .setDiarySortPreference(mealType.name, sortType.index);
  }

  @override
  Widget build(BuildContext context) {
    final trackedDay = widget.trackedDayEntity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMMEEEEd().format(widget.selectedDay),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (_allIntakes.isNotEmpty)
                Semantics(
                  identifier: 'diary-repeat-day',
                  child: IconButton(
                    icon: const Icon(Icons.content_copy_outlined),
                    tooltip: S.of(context).repeatDayActionLabel,
                    onPressed: () => showCopyDayDialog(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            trackedDay == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      S.of(context).nothingAddedLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  )
                : const SizedBox(),
            trackedDay != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 0.0,
                          margin: const EdgeInsets.all(0.0),
                          color: widget.trackedDayEntity
                              ?.getRatingDayTextBackgroundColor(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            child: Text(
                              _getCaloriesTrackedDisplayString(
                                  context, trackedDay),
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                    color: widget.trackedDayEntity
                                        ?.getRatingDayTextColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        MacroNutrientsView(
                          totalCarbsIntake: _allIntakes
                              .fold(0.0, (sum, i) => sum + i.totalCarbsGram),
                          totalFatsIntake: _allIntakes
                              .fold(0.0, (sum, i) => sum + i.totalFatsGram),
                          totalProteinsIntake: _allIntakes
                              .fold(0.0, (sum, i) => sum + i.totalProteinsGram),
                          totalCarbsGoal: trackedDay.carbsGoal ?? 0.0,
                          totalFatsGoal: trackedDay.fatGoal ?? 0.0,
                          totalProteinsGoal: trackedDay.proteinGoal ?? 0.0,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(),
            // #160 + #173 + #404: Daily micronutrient panel — aggregates
            // ten nutrients (fibre, sodium, saturated fat, sugar, calcium,
            // iron, potassium, vitamin D, vitamin B12, magnesium) across
            // the day's intake list, with a Day/Week toggle that pulls the
            // previous six days' intakes itself via the locator. The
            // tracked-day entity is forwarded so the panel can prefer the
            // user's per-nutrient targets from Settings → Nutrient goals
            // when they've configured any (#173). No-op when there's
            // nothing logged for the current day yet.
            if (_allIntakes.isNotEmpty)
              DailyNutrientPanel(
                intakes: _allIntakes,
                selectedDay: widget.selectedDay,
                trackedDay: widget.trackedDayEntity,
              ),
            if (widget.showActivityTracking) ...[
              const SizedBox(height: 8.0),
              ActivityVerticalList(
                day: widget.selectedDay,
                title: S.of(context).activityLabel,
                userActivityList: widget.userActivities,
                onItemLongPressedCallback: onActivityItemLongPressed,
                onItemTappedCallback: widget.onEditActivity,
                onCopyActivityCallback:
                    DateUtils.isSameDay(widget.selectedDay, DateTime.now())
                        ? null
                        : (activity) =>
                            widget.onCopyActivity(activity, widget.trackedDayEntity),
              ),
            ],
            // #150 follow-up: a 0% share hides the section entirely so OMAD
            // users (and anyone else who's set a meal slot to 0%) don't see
            // a meal type they explicitly opted out of. Logged intakes for a
            // hidden section still count toward the day's totals.
            if (widget.breakfastSharePct > 0)
              IntakeVerticalList(
                day: widget.selectedDay,
                title: S.of(context).breakfastLabel,
                listIcon: Icons.bakery_dining_outlined,
                addMealType: AddMealType.breakfastType,
                intakeList: _sortByMeal[IntakeTypeEntity.breakfast]!
                    .apply(widget.breakfastIntake),
                onDeleteIntakeCallback: widget.onDeleteIntake,
                onItemLongPressedCallback: onIntakeItemLongPressed,
                onItemTappedCallback: widget.onEditIntake,
                onCopyIntakeCallback:
                    DateUtils.isSameDay(widget.selectedDay, DateTime.now())
                        ? null
                        : widget.onCopyIntake,
                usesImperialUnits: widget.usesImperialUnits,
                showMealMacros: widget.showMealMacros,
                trackedDayEntity: trackedDay,
                mealKcalTarget: widget.breakfastKcalTarget,
                sortType: _sortByMeal[IntakeTypeEntity.breakfast],
                onSortTypeChanged: (sort) =>
                    _setSortFor(IntakeTypeEntity.breakfast, sort),
              ),
            if (widget.lunchSharePct > 0)
              IntakeVerticalList(
                day: widget.selectedDay,
                title: S.of(context).lunchLabel,
                listIcon: Icons.lunch_dining_outlined,
                addMealType: AddMealType.lunchType,
                intakeList: _sortByMeal[IntakeTypeEntity.lunch]!
                    .apply(widget.lunchIntake),
                onDeleteIntakeCallback: widget.onDeleteIntake,
                onItemLongPressedCallback: onIntakeItemLongPressed,
                onItemTappedCallback: widget.onEditIntake,
                usesImperialUnits: widget.usesImperialUnits,
                showMealMacros: widget.showMealMacros,
                onCopyIntakeCallback:
                    DateUtils.isSameDay(widget.selectedDay, DateTime.now())
                        ? null
                        : widget.onCopyIntake,
                trackedDayEntity: trackedDay,
                mealKcalTarget: widget.lunchKcalTarget,
                sortType: _sortByMeal[IntakeTypeEntity.lunch],
                onSortTypeChanged: (sort) =>
                    _setSortFor(IntakeTypeEntity.lunch, sort),
              ),
            if (widget.dinnerSharePct > 0)
              IntakeVerticalList(
                day: widget.selectedDay,
                title: S.of(context).dinnerLabel,
                listIcon: Icons.dinner_dining_outlined,
                addMealType: AddMealType.dinnerType,
                intakeList: _sortByMeal[IntakeTypeEntity.dinner]!
                    .apply(widget.dinnerIntake),
                onDeleteIntakeCallback: widget.onDeleteIntake,
                onItemLongPressedCallback: onIntakeItemLongPressed,
                onItemTappedCallback: widget.onEditIntake,
                onCopyIntakeCallback:
                    DateUtils.isSameDay(widget.selectedDay, DateTime.now())
                        ? null
                        : widget.onCopyIntake,
                usesImperialUnits: widget.usesImperialUnits,
                showMealMacros: widget.showMealMacros,
                mealKcalTarget: widget.dinnerKcalTarget,
                sortType: _sortByMeal[IntakeTypeEntity.dinner],
                onSortTypeChanged: (sort) =>
                    _setSortFor(IntakeTypeEntity.dinner, sort),
              ),
            if (widget.snackSharePct > 0)
              IntakeVerticalList(
                day: widget.selectedDay,
                title: S.of(context).snackLabel,
                listIcon: CustomIcons.food_apple_outline,
                addMealType: AddMealType.snackType,
                intakeList: _sortByMeal[IntakeTypeEntity.snack]!
                    .apply(widget.snackIntake),
                onDeleteIntakeCallback: widget.onDeleteIntake,
                onItemLongPressedCallback: onIntakeItemLongPressed,
                onItemTappedCallback: widget.onEditIntake,
                usesImperialUnits: widget.usesImperialUnits,
                showMealMacros: widget.showMealMacros,
                onCopyIntakeCallback:
                    DateUtils.isSameDay(widget.selectedDay, DateTime.now())
                        ? null
                        : widget.onCopyIntake,
                trackedDayEntity: trackedDay,
                mealKcalTarget: widget.snackKcalTarget,
                sortType: _sortByMeal[IntakeTypeEntity.snack],
                onSortTypeChanged: (sort) =>
                    _setSortFor(IntakeTypeEntity.snack, sort),
              ),
            const SizedBox(height: 16.0),
          ],
        ),
      ],
    );
  }

  // #182: Compute from actual intakes instead of stale cached values
  List<IntakeEntity> get _allIntakes => [
        ...widget.breakfastIntake,
        ...widget.lunchIntake,
        ...widget.dinnerIntake,
        ...widget.snackIntake,
      ];

  String _getCaloriesTrackedDisplayString(
      BuildContext context, TrackedDayEntity trackedDay) {
    final actualKcal = _allIntakes.fold(0.0, (sum, i) => sum + i.totalKcal);
    final usesKilojoules =
        context.watch<EnergyUnitProvider>().usesKilojoules;
    final clampedKcal = actualKcal < 0 ? 0.0 : actualKcal;
    final displayActual = usesKilojoules
        ? UnitCalc.kcalToKj(clampedKcal).round()
        : clampedKcal.round();
    final displayGoal = usesKilojoules
        ? UnitCalc.kcalToKj(trackedDay.calorieGoal).round()
        : trackedDay.calorieGoal.round();
    final unit = usesKilojoules ? S.of(context).kjLabel : S.of(context).kcalLabel;
    return '$displayActual/$displayGoal $unit';
  }

  /// FR-09: copy every intake item logged this day (breakfast through
  /// snack) to another day or range of days in one action, instead of
  /// per-item or per-meal-section. Each item keeps its own original meal
  /// type at the target date(s) — same single-item copy FR-06/FR-08
  /// already do, just looped over every item and every day in the chosen
  /// range. Copy only (no move): moving a whole day would empty today,
  /// a much rarer thing to want than duplicating it forward.
  void showCopyDayDialog(BuildContext context) async {
    final intakes = _allIntakes;
    if (intakes.isEmpty) return;

    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => CopyDayDialog(
        // Defaults one day past whatever day is being viewed, not
        // DateTime.now() — the natural reading of "repeat this day" is
        // forward, and defaulting onto the source day itself would make
        // a reflexive OK tap duplicate every item back onto the day the
        // user is already looking at.
        initialDate: CalendarDayCalc.addDays(widget.selectedDay, 1),
      ),
    );
    if (result == null || !context.mounted) return;

    for (
      var day = DateTime(result.start.year, result.start.month, result.start.day);
      !day.isAfter(result.end);
      day = CalendarDayCalc.addDays(day, 1)
    ) {
      for (final intake in intakes) {
        // null type keeps each item on its own original meal — the whole
        // point of a whole-day copy over a per-meal-section one.
        await widget.onCopyIntake(intake, null, null, day);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).dayCopiedSnackbar(intakes.length)),
        ),
      );
    }
  }

  void showCopyOrDeleteIntakeDialog(
    BuildContext context,
    IntakeEntity intakeEntity,
  ) async {
    final action = await showDialog<CopyOrDeleteAction>(
      context: context,
      builder: (context) => CopyOrDeleteDialog(
        copyLabel: S.of(context).copyActionLabel,
        showMoveOption: true,
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case CopyOrDeleteAction.delete:
        showDeleteIntakeDialog(context, intakeEntity);
      case CopyOrDeleteAction.copy:
        showCopyDialog(context, intakeEntity, move: false);
      case CopyOrDeleteAction.move:
        showCopyDialog(context, intakeEntity, move: true);
    }
  }

  void showCopyDialog(
    BuildContext context,
    IntakeEntity intakeEntity, {
    required bool move,
  }) async {
    final defaultMealType = switch (intakeEntity.type) {
      IntakeTypeEntity.breakfast => AddMealType.breakfastType,
      IntakeTypeEntity.lunch => AddMealType.lunchType,
      IntakeTypeEntity.dinner => AddMealType.dinnerType,
      IntakeTypeEntity.snack => AddMealType.snackType,
    };

    final copyDialog = CopyDialog(
      initialValue: defaultMealType,
      initialDate: DateTime.now(),
    );
    final result = await showDialog<CopyDialogResult>(
      context: context,
      builder: (context) => copyDialog,
    );
    if (result != null) {
      final (selectedMealType, startDate, endDate) = result;
      // A date range is FR-06's single-day copy applied once per day in
      // [startDate, endDate] — same mechanism, no new data-layer logic.
      // Sequential awaits (not a Future.wait) so days never race each
      // other's TrackedDayDBO update.
      for (
        var day = startDate;
        !day.isAfter(endDate);
        day = CalendarDayCalc.addDays(day, 1)
      ) {
        await widget.onCopyIntake(intakeEntity, null, selectedMealType, day);
      }
      // Move = the copy above, then the same delete "Delete" already
      // performs on the original — awaited so the delete never races the
      // copy's write to the target day(s). isMove swaps the confirmation
      // snackbar's wording so it doesn't read as an accidental deletion.
      if (move) {
        widget.onDeleteIntake(
          intakeEntity,
          widget.trackedDayEntity,
          isMove: true,
        );
      }
    }
  }

  void showDeleteIntakeDialog(
    BuildContext context,
    IntakeEntity intakeEntity,
  ) async {
    final shouldDeleteIntake = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );
    if (shouldDeleteIntake != null) {
      widget.onDeleteIntake(intakeEntity, widget.trackedDayEntity);
    }
  }

  // Previously skipped straight to the delete-only dialog when viewing
  // today, since copying only ever targeted today anyway (a no-op from
  // today's own view). Now that CopyDialog lets the user pick any target
  // day, copying from today (e.g. "move this to tomorrow") is a real,
  // useful action, so the copy-or-delete choice is offered unconditionally.
  void onIntakeItemLongPressed(
    BuildContext context,
    IntakeEntity intakeEntity,
  ) async {
    showCopyOrDeleteIntakeDialog(context, intakeEntity);
  }

  void onActivityItemLongPressed(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    if (DateUtils.isSameDay(widget.selectedDay, DateTime.now())) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => const DeleteDialog(),
      );
      if (shouldDelete != null) {
        widget.onDeleteActivity(activityEntity, widget.trackedDayEntity);
      }
    } else {
      final copyOrDelete = await showDialog<CopyOrDeleteAction>(
        context: context,
        builder: (context) => const CopyOrDeleteDialog(),
      );
      if (context.mounted) {
        if (copyOrDelete == CopyOrDeleteAction.delete) {
          widget.onDeleteActivity(activityEntity, widget.trackedDayEntity);
        } else if (copyOrDelete == CopyOrDeleteAction.copy) {
          widget.onCopyActivity(activityEntity, widget.trackedDayEntity);
        }
      }
    }
  }
}
