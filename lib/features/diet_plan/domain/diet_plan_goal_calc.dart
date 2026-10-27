import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';

/// Result of turning a plan (kg to lose, pace) into the daily kcal goal the
/// existing engine produces, and whether the kcal floor had to step in.
typedef PlanGoal = ({double goalKcal, double rawKcal, double floorKcal, bool floorApplied});

/// Bridges a diet plan to the existing calorie engine: no deficit formula of
/// its own, only the target weight and the weekly rate the engine already
/// reads.
class DietPlanGoalCalc {
  /// Lowest weight the plan's target may land on, so a large "kg to lose"
  /// never produces an absurd target.
  static const double minTargetWeightKg = 30;

  /// Most kilograms a plan for [weightKg] can ask to lose (steps of 0.5).
  static double maxLossFor(double weightKg) {
    final room = weightKg - minTargetWeightKg;
    final steps = (room / DietPlanCalc.lossStepKg).floor();
    final capped = steps * DietPlanCalc.lossStepKg;
    return capped.clamp(DietPlanCalc.minLossKg, DietPlanCalc.maxLossKg);
  }

  /// [kg] snapped to the 0.5 steps and kept inside what [weightKg] allows.
  static double clampLoss(double kg, double weightKg) {
    final snapped = (kg / DietPlanCalc.lossStepKg).round() * DietPlanCalc.lossStepKg;
    return snapped.clamp(DietPlanCalc.minLossKg, maxLossFor(weightKg));
  }

  /// The engine's `weeklyRatePct` for a pace in kg per week: pace over body
  /// weight, in percent (the engine's unit: % of body weight per week), kept
  /// inside the range the Profile picker offers.
  static double weeklyRatePct(double weightKg, double paceKgPerWeek) =>
      (paceKgPerWeek / weightKg * 100).clamp(GoalRateCalc.minRatePct, GoalRateCalc.maxRatePct);

  /// Writes the plan into [user]: target weight = [baseWeightKg] (default
  /// the current weight) - kg, rate = pace as a percentage of body weight.
  static void applyToUser(
    UserEntity user, {
    required double kgToLose,
    required double paceKgPerWeek,
    double? baseWeightKg,
  }) {
    final base = baseWeightKg ?? user.weightKG;
    user
      ..targetWeightKg = base - clampLoss(kgToLose, base)
      ..weeklyRatePct = weeklyRatePct(user.weightKG, paceKgPerWeek);
  }

  /// The goal the engine gives [user] before any check-in data exists, with
  /// the floor applied and flagged.
  static PlanGoal goalFor(UserEntity user) {
    final raw = CalorieGoalCalc.getStaticCoreGoal(user);
    final floor = CalorieGoalCalc.recommendedDailyKcalFloor(gender: user.gender, caloriesProfile: user.caloriesProfile);
    final applied = raw < floor;
    return (goalKcal: applied ? floor : raw, rawKcal: raw, floorKcal: floor, floorApplied: applied);
  }

  /// The highest offered pace below [currentPace] that keeps [user]'s goal
  /// at or above the floor, or null when none does (or the current pace is
  /// already fine).
  static double? suggestedPace(UserEntity user, {required double kgToLose, required double currentPace}) {
    if (user.goal != UserWeightGoalEntity.loseWeight) return null;
    if (!_floorApplies(user, kgToLose, currentPace)) return null;
    final lower = DietPlanCalc.paceOptions.where((p) => p < currentPace).toList()..sort();
    for (final p in lower.reversed) {
      if (!_floorApplies(user, kgToLose, p)) return p;
    }
    return null;
  }

  static bool _floorApplies(UserEntity user, double kgToLose, double pace) {
    final probe = UserEntity(
      birthday: user.birthday,
      heightCM: user.heightCM,
      weightKG: user.weightKG,
      gender: user.gender,
      goal: user.goal,
      pal: user.pal,
      caloriesProfile: user.caloriesProfile,
      targetWeightKg: user.targetWeightKg,
      weeklyRatePct: user.weeklyRatePct,
      caloriesTaperEnabled: user.caloriesTaperEnabled,
    );
    applyToUser(probe, kgToLose: kgToLose, paceKgPerWeek: pace);
    return goalFor(probe).floorApplied;
  }
}
