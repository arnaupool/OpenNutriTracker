import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/presentation/goal_explanation.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';

// FM-14 (AUDIT.md B3/B4).
void main() {
  double rateKcal(double pct, double kg) => pct / 100 * kg * DynamicMaintenanceCalc.kcalPerKgBodyMass / 7;

  UserEntity user({double? weeklyRatePct, double? weeklyWeightGoalKg}) => UserEntity(
    birthday: DateTime(1994, 1, 1),
    heightCM: 178,
    weightKG: 80,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.loseWeight,
    pal: UserPALEntity.lowActive,
    weeklyRatePct: weeklyRatePct,
    weeklyWeightGoalKg: weeklyWeightGoalKg,
  );

  group('effectiveRatePct', () {
    test('uses the picked rate', () {
      expect(GoalRateCalc.effectiveRatePct(user(weeklyRatePct: 0.75)), 0.75);
    });
    test('converts the legacy kg/week rate to % of body weight', () {
      expect(GoalRateCalc.effectiveRatePct(user(weeklyWeightGoalKg: -0.4)), closeTo(0.5, 1e-9));
    });
    test('falls back to the 0.5% default', () {
      expect(GoalRateCalc.effectiveRatePct(user()), GoalRateCalc.defaultRatePct);
    });
  });

  group('adjustment', () {
    test('lose, far from target: deficit at the chosen rate of trend weight', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.loseWeight,
        trendWeightKg: 90,
        targetWeightKg: 80,
        ratePct: 1.0,
      );
      expect(a.phase, GoalPhase.rate);
      expect(a.adjustmentKcal, closeTo(-rateKcal(1.0, 90), 1e-9));
    });

    test('gain, far from target: surplus at the chosen rate', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.gainWeight,
        trendWeightKg: 70,
        targetWeightKg: 75,
        ratePct: 0.25,
      );
      expect(a.phase, GoalPhase.rate);
      expect(a.adjustmentKcal, closeTo(rateKcal(0.25, 70), 1e-9));
    });

    test('lose, within 0.7 kg of target: maintenance, no adjustment', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.loseWeight,
        trendWeightKg: 80.5,
        targetWeightKg: 80,
        ratePct: 1.0,
      );
      expect(a.phase, GoalPhase.withinBand);
      expect(a.adjustmentKcal, 0);
    });

    test('lose, already well below target: nudged back up at 0.15%/week', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.loseWeight,
        trendWeightKg: 78,
        targetWeightKg: 80,
        ratePct: 1.0,
      );
      expect(a.phase, GoalPhase.correcting);
      expect(a.adjustmentKcal, closeTo(rateKcal(0.15, 78), 1e-9));
    });

    test('maintain with target outside the band: 0.15%/week correction', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.maintainWeight,
        trendWeightKg: 81,
        targetWeightKg: 80,
        ratePct: 1.0,
      );
      expect(a.phase, GoalPhase.correcting);
      expect(a.adjustmentKcal, closeTo(-rateKcal(0.15, 81), 1e-9));
    });

    test('maintain without target: plain TDEE', () {
      final a = GoalRateCalc.adjustment(
        goal: UserWeightGoalEntity.maintainWeight,
        trendWeightKg: 81,
        targetWeightKg: null,
        ratePct: 1.0,
      );
      expect(a.phase, GoalPhase.maintaining);
      expect(a.adjustmentKcal, 0);
    });
  });

  test('formatRatePct trims trailing zeros', () {
    expect(formatRatePct(0.5), '0.5');
    expect(formatRatePct(0.75), '0.75');
    expect(formatRatePct(1.0), '1');
    expect(formatRatePct(0.1), '0.1');
  });
}
