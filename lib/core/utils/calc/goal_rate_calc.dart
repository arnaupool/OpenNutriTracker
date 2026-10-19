import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';

/// Which rule set today's dynamic goal (FM-14):
///
/// - [maintaining]: maintain goal with no target weight, goal = TDEE.
/// - [withinBand]: trend inside [DynamicMaintenanceCalc.maintenanceBandKg]
///   of the target, goal = TDEE.
/// - [correcting]: maintain goal (or a lose/gain goal already past its
///   target) outside the band, nudged back at 0.15%/week.
/// - [rate]: lose/gain goal still short of its target, at the chosen
///   % of body weight per week.
enum GoalPhase { maintaining, withinBand, correcting, rate }

typedef GoalAdjustment = ({GoalPhase phase, double adjustmentKcal});

class GoalRateCalc {
  /// Used until the user picks a rate. MacroFactor's own worked example
  /// of a weight-loss goal is 0.5% of body weight per week
  /// (https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal).
  static const double defaultRatePct = 0.5;

  /// Bounds and step of the Profile rate picker.
  static const double minRatePct = 0.1;
  static const double maxRatePct = 1.5;
  static const double ratePctStep = 0.05;

  /// The rate the dynamic engine applies: the user's pick, else their old
  /// kg/week rate converted to % of [UserEntity.weightKG], else
  /// [defaultRatePct].
  static double effectiveRatePct(UserEntity user) {
    final pct = user.weeklyRatePct;
    if (pct != null) return pct;
    final legacyKg = user.weeklyWeightGoalKg;
    if (legacyKg != null && legacyKg != 0 && user.weightKG > 0) {
      return (legacyKg.abs() / user.weightKG * 100).clamp(minRatePct, maxRatePct);
    }
    return defaultRatePct;
  }

  /// Daily kcal deficit (or surplus) that changes [weightKg] by [ratePct]
  /// percent per week, using the same energy density as the rest of the
  /// engine.
  static double rateKcalPerDay({
    required double ratePct,
    required double weightKg,
  }) => ratePct / 100 * weightKg * DynamicMaintenanceCalc.kcalPerKgBodyMass / 7;

  /// The adjustment on top of the dynamic TDEE. MacroFactor sets lose/gain
  /// goals as a % of body weight per week
  /// (https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal)
  /// and keeps the ±1.5 lb band with its 0.15%/week nudge for the
  /// maintenance goal
  /// (https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor).
  /// Once a lose/gain trend reaches its target, the maintenance rules take
  /// over around that target.
  static GoalAdjustment adjustment({
    required UserWeightGoalEntity goal,
    required double trendWeightKg,
    required double? targetWeightKg,
    required double ratePct,
  }) {
    if (goal == UserWeightGoalEntity.maintainWeight) {
      if (targetWeightKg == null) {
        return (phase: GoalPhase.maintaining, adjustmentKcal: 0.0);
      }
      return _maintenance(trendWeightKg, targetWeightKg);
    }

    final losing = goal == UserWeightGoalEntity.loseWeight;
    if (targetWeightKg != null) {
      final remainingKg = losing
          ? trendWeightKg - targetWeightKg
          : targetWeightKg - trendWeightKg;
      if (remainingKg <= DynamicMaintenanceCalc.maintenanceBandKg) {
        return _maintenance(trendWeightKg, targetWeightKg);
      }
    }

    final kcal = rateKcalPerDay(ratePct: ratePct, weightKg: trendWeightKg);
    return (phase: GoalPhase.rate, adjustmentKcal: losing ? -kcal : kcal);
  }

  static GoalAdjustment _maintenance(double trendWeightKg, double targetWeightKg) {
    final adjustment =
        DynamicMaintenanceCalc.recommendedKcal(
          trendWeightKg: trendWeightKg,
          goalWeightKg: targetWeightKg,
          tdeeKcal: 0,
        );
    return (
      phase: adjustment == 0 ? GoalPhase.withinBand : GoalPhase.correcting,
      adjustmentKcal: adjustment,
    );
  }
}
