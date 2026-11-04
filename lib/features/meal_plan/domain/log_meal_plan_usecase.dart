import 'package:flutter/foundation.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';

/// "Log plan" (FAS-04) and the Diary's per-entry "Confirm": turn planned
/// entries into diary intakes and mark them logged so a second tap can't
/// duplicate them. Until then a planned entry counts nowhere.
class LogMealPlanUsecase {
  final MealPlanDataSource _plan;
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDays;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;

  LogMealPlanUsecase(this._plan, this._addIntake, this._trackedDays, this._kcalGoal, this._macroGoal);

  /// Entries of [day] still waiting for a decision: neither logged nor
  /// discarded. They are what the Diary shows as "planned".
  List<MealPlanEntryDBO> pendingFor(DateTime day) =>
      _plan.entriesBetween(day, day).where((e) => e.isPending).toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Notifies when the plan changes (local edits and synced ones).
  Listenable listenable() => _plan.listenable();

  final Set<String> _inFlight = {};

  /// Logs every pending entry of [day]; returns how many were logged.
  Future<int> logDay(DateTime day, {DateTime? now}) async {
    var logged = 0;
    for (final entry in pendingFor(day)) {
      if (await confirm(entry.id, now: now)) logged++;
    }
    return logged;
  }

  /// Turns one planned entry into a normal diary intake of its day and meal,
  /// with the planned quantity, and marks the entry logged. Reads the entry
  /// fresh, so a plan edited since the Diary was drawn logs the current
  /// quantity, and a second call (double tap, another screen) does nothing:
  /// returns whether an intake was created.
  Future<bool> confirm(String entryId, {DateTime? now}) async {
    if (!_inFlight.add(entryId)) return false;
    try {
      final entry = _plan.get(entryId);
      if (entry == null || !entry.isPending) return false;
      final logicalDay = DateTime(entry.day.year, entry.day.month, entry.day.day);
      if (!await _trackedDays.hasTrackedDay(logicalDay)) {
        final kcal = await _kcalGoal.getKcalGoal();
        await _trackedDays.addNewTrackedDay(
          logicalDay,
          kcal,
          await _macroGoal.getCarbsGoal(kcal),
          await _macroGoal.getFatsGoal(kcal),
          await _macroGoal.getProteinsGoal(kcal),
        );
      }
      final type = IntakeTypeEntity.fromIntakeTypeDBO(entry.type);
      final intake = IntakeEntity(
        // One intake per plan entry, also across devices that confirm the
        // same entry before they sync.
        id: 'plan-${entry.id}',
        unit: entry.unit,
        amount: entry.amount,
        type: type,
        meal: MealEntity.fromMealDBO(entry.meal),
        dateTime: logicalDay.add(Duration(hours: _typicalHour(type))),
      );
      await _addIntake.addIntake(intake);
      await _trackedDays.addDayCaloriesTracked(logicalDay, intake.totalKcal);
      await _trackedDays.addDayMacrosTracked(
        logicalDay,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
      await _plan.save(entry.copyWith(loggedAt: now ?? DateTime.now()));
      return true;
    } finally {
      _inFlight.remove(entryId);
    }
  }

  /// Hides a planned entry from the Diary for its day. It stays in the plan.
  Future<void> discard(String entryId, {DateTime? now}) async {
    final entry = _plan.get(entryId);
    if (entry == null || !entry.isPending) return;
    await _plan.save(entry.copyWith(discardedAt: now ?? DateTime.now()));
  }

  /// When the diary shows the logged intake; any hour of the right day
  /// works, these just keep the order natural.
  static int _typicalHour(IntakeTypeEntity type) => switch (type) {
    IntakeTypeEntity.breakfast => 8,
    IntakeTypeEntity.lunch => 14,
    IntakeTypeEntity.snack => 17,
    IntakeTypeEntity.dinner => 21,
  };
}
