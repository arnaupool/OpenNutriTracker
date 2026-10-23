import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';

/// "Log plan" (FAS-04): turns a day's planned entries into diary intakes in
/// one go, and marks them logged so a second tap can't duplicate them.
class LogMealPlanUsecase {
  final MealPlanDataSource _plan;
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDays;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;

  LogMealPlanUsecase(this._plan, this._addIntake, this._trackedDays, this._kcalGoal, this._macroGoal);

  /// Unlogged entries of [day].
  List<MealPlanEntryDBO> pendingFor(DateTime day) =>
      _plan.entriesBetween(day, day).where((e) => e.loggedAt == null).toList();

  /// Logs every pending entry of [day]; returns how many were logged.
  Future<int> logDay(DateTime day, {DateTime? now}) async {
    final pending = pendingFor(day);
    if (pending.isEmpty) return 0;
    final logicalDay = DateTime(day.year, day.month, day.day);
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
    for (final entry in pending) {
      final type = IntakeTypeEntity.fromIntakeTypeDBO(entry.type);
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
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
    }
    return pending.length;
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
