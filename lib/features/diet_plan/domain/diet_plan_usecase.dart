import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_data_source.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_goal_calc.dart';

/// Reads and changes the diet plan and keeps the calorie engine's target
/// weight and weekly rate in step with it.
class DietPlanUsecase {
  final DietPlanDataSource _dataSource;
  final WeightLogRepository _weightLog;
  final UserRepository _users;

  /// Saves the user the way Profile does (new goal or target restarts the
  /// program, today's tracked goal and the pages refresh).
  final Future<void> Function(UserEntity user) _updateUser;

  DietPlanUsecase(this._dataSource, this._weightLog, this._users, this._updateUser);

  DietPlanDBO? get plan => _dataSource.get();

  ValueListenable<Box<DietPlanDBO>> get listenable => _dataSource.listenable();

  Future<void> save(DietPlanDBO plan) => _dataSource.save(plan);

  /// A new automatic plan starting [start].
  static DietPlanDBO newAutoPlan({
    required DateTime start,
    required double startWeightKg,
    required double kgToLose,
    required double paceKgPerWeek,
    bool showCountdown = true,
  }) {
    final day = DietPlanCalc.dateOnly(start);
    return DietPlanDBO(
      mode: DietPlanMode.auto,
      startDate: day,
      endDate: DietPlanCalc.autoEnd(day, kgToLose, paceKgPerWeek),
      startWeightKg: startWeightKg,
      targetLossKg: kgToLose,
      paceKgPerWeek: paceKgPerWeek,
      showCountdown: showCountdown,
    );
  }

  Future<List<WeightPoint>> weightPoints() async {
    final entries = await _weightLog.getAllEntries();
    return [for (final e in entries) (date: e.date, weightKg: e.weightKg)];
  }

  /// Saves [plan] and, for an automatic plan, writes its target weight and
  /// pace into the calorie engine (the plan aims to lose weight, so the
  /// goal becomes "lose").
  Future<void> saveAndSync(DietPlanDBO plan) async {
    await _dataSource.save(plan);
    final kg = plan.targetLossKg;
    final pace = plan.paceKgPerWeek;
    if (plan.mode != DietPlanMode.auto || kg == null || pace == null) return;
    final user = await _users.getUserData();
    user.goal = UserWeightGoalEntity.loseWeight;
    DietPlanGoalCalc.applyToUser(user, kgToLose: kg, paceKgPerWeek: pace, baseWeightKg: plan.startWeightKg);
    await _updateUser(user);
  }

  Future<void> pause([DateTime? now]) async {
    final p = plan;
    if (p == null) return;
    await _dataSource.save(DietPlanCalc.pause(p, now ?? DateTime.now()));
  }

  Future<void> resume([DateTime? now]) async {
    final p = plan;
    if (p == null) return;
    await _dataSource.save(DietPlanCalc.resume(p, now ?? DateTime.now()));
  }

  Future<void> setShowCountdown(bool show) async {
    final p = plan;
    if (p == null) return;
    await _dataSource.save(p.copyWith(showCountdown: show));
  }

  /// Moves the plan's end to [end] (a manual end date) and reopens it.
  Future<void> extendTo(DateTime end, [DateTime? now]) async {
    final p = plan;
    if (p == null) return;
    final today = now ?? DateTime.now();
    final extended = DietPlanCalc.withEffectiveEnd(p.copyWith(mode: DietPlanMode.manual), end, today);
    await _dataSource.save(extended.copyWith(status: DietPlanStatus.active));
  }

  /// The weight to start a new plan from: the 7-day average, else the last
  /// weigh-in, else the profile weight.
  Future<double> currentWeightKg([DateTime? now]) async {
    final today = now ?? DateTime.now();
    final points = await weightPoints();
    final average = DietPlanCalc.windowAverage(points, today);
    if (average != null) return average;
    if (points.isNotEmpty) {
      final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
      return sorted.last.weightKg;
    }
    return (await _users.getUserData()).weightKG;
  }

  /// Replaces the plan with a fresh automatic one starting today, aiming at
  /// the profile's target weight when it is below the current weight, else
  /// 5 kg, and keeping the countdown preference. The new plan is stored and returned.
  Future<DietPlanDBO> startNewPlan([DateTime? now]) async {
    final today = DietPlanCalc.dateOnly(now ?? DateTime.now());
    final user = await _users.getUserData();
    final weight = await currentWeightKg(today);
    final target = user.targetWeightKg;
    final kg = target != null && target < weight
        ? DietPlanGoalCalc.clampLoss(weight - target, weight)
        : DietPlanGoalCalc.clampLoss(5, weight);
    final pace = plan?.paceKgPerWeek ?? DietPlanCalc.defaultPaceKgPerWeek;
    final fresh = newAutoPlan(
      start: today,
      startWeightKg: weight,
      kgToLose: kg,
      paceKgPerWeek: pace,
      showCountdown: plan?.showCountdown ?? true,
    );
    await saveAndSync(fresh);
    return fresh;
  }

  /// Ends the plan: the goal becomes "maintain", the plan is marked
  /// finished and its countdown hidden.
  Future<void> switchToMaintenance() async {
    final p = plan;
    if (p != null) {
      await _dataSource.save(p.copyWith(status: DietPlanStatus.finished, showCountdown: false));
    }
    final user = await _users.getUserData();
    user.goal = UserWeightGoalEntity.maintainWeight;
    await _updateUser(user);
  }
}
