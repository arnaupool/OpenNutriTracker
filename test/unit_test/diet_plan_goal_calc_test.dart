import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_goal_calc.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_data_mask_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_activity_selection_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_gender_selection_entity.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_goal_selection_entity.dart';

UserEntity _user({
  UserGenderEntity gender = UserGenderEntity.female,
  double weight = 50,
  double height = 155,
  CaloriesProfileEntity? profile,
}) => UserEntity(
  birthday: DateTime(DateTime.now().year - 40, 1, 1),
  heightCM: height,
  weightKG: weight,
  gender: gender,
  goal: UserWeightGoalEntity.loseWeight,
  pal: UserPALEntity.sedentary,
  caloriesProfile: profile,
);

void main() {
  group('kcal floor', () {
    test('is 1500 for men, 1200 for women and 1350 for non-binary', () {
      double floor(UserGenderEntity g, [CaloriesProfileEntity? p]) =>
          CalorieGoalCalc.recommendedDailyKcalFloor(gender: g, caloriesProfile: p);
      expect(floor(UserGenderEntity.male), 1500);
      expect(floor(UserGenderEntity.female), 1200);
      expect(floor(UserGenderEntity.nonBinary), 1350);
      expect(floor(UserGenderEntity.nonBinary, CaloriesProfileEntity.averaged), 1350);
      expect(floor(UserGenderEntity.nonBinary, CaloriesProfileEntity.testosteroneTypical), 1500);
      expect(floor(UserGenderEntity.nonBinary, CaloriesProfileEntity.estrogenTypical), 1200);
    });

    test('reports when it applied and never returns less than the floor', () {
      final user = _user();
      DietPlanGoalCalc.applyToUser(user, kgToLose: 10, paceKgPerWeek: 0.75);
      final goal = DietPlanGoalCalc.goalFor(user);
      expect(goal.rawKcal, lessThan(1200));
      expect(goal.floorApplied, isTrue);
      expect(goal.goalKcal, 1200);
      expect(goal.floorKcal, 1200);
    });

    test('does not flag a goal above the floor', () {
      final user = _user(gender: UserGenderEntity.male, weight: 90, height: 185);
      DietPlanGoalCalc.applyToUser(user, kgToLose: 10, paceKgPerWeek: 0.5);
      final goal = DietPlanGoalCalc.goalFor(user);
      expect(goal.floorApplied, isFalse);
      expect(goal.goalKcal, goal.rawKcal);
      expect(goal.goalKcal, greaterThan(1500));
    });

    test('suggests the highest lower pace that clears the floor', () {
      final user = _user();
      DietPlanGoalCalc.applyToUser(user, kgToLose: 10, paceKgPerWeek: 0.75);
      final suggested = DietPlanGoalCalc.suggestedPace(user, kgToLose: 10, currentPace: 0.75);
      expect(suggested, isNotNull);
      expect(suggested, lessThan(0.75));
      // The suggestion really clears the floor.
      final probe = _user();
      DietPlanGoalCalc.applyToUser(probe, kgToLose: 10, paceKgPerWeek: suggested!);
      expect(DietPlanGoalCalc.goalFor(probe).floorApplied, isFalse);
    });

    test('no suggestion when the chosen pace already clears the floor', () {
      final user = _user(gender: UserGenderEntity.male, weight: 90, height: 185);
      DietPlanGoalCalc.applyToUser(user, kgToLose: 10, paceKgPerWeek: 0.5);
      expect(DietPlanGoalCalc.suggestedPace(user, kgToLose: 10, currentPace: 0.5), isNull);
    });
  });

  group('plan to engine mapping', () {
    test('target weight is weight minus kg and the rate is the pace as % of body weight', () {
      final user = _user(weight: 80, height: 180);
      DietPlanGoalCalc.applyToUser(user, kgToLose: 10, paceKgPerWeek: 0.5);
      expect(user.targetWeightKg, 70);
      expect(user.weeklyRatePct, closeTo(0.5 / 80 * 100, 1e-9));
      // The engine reads that percentage as kg per week of the current weight.
      expect(GoalRateCalc.effectiveRatePct(user) / 100 * 80, closeTo(0.5, 1e-9));
    });

    test('the rate stays inside the range the engine offers', () {
      final user = _user(weight: 35);
      DietPlanGoalCalc.applyToUser(user, kgToLose: 2, paceKgPerWeek: 0.75);
      expect(user.weeklyRatePct, GoalRateCalc.maxRatePct);
    });

    test('loss is snapped to half kilos and kept inside what the weight allows', () {
      expect(DietPlanGoalCalc.clampLoss(10.3, 80), 10.5);
      expect(DietPlanGoalCalc.clampLoss(0.1, 80), 0.5);
      expect(DietPlanGoalCalc.clampLoss(60, 120), 50);
      expect(DietPlanGoalCalc.clampLoss(30, 45), DietPlanGoalCalc.maxLossFor(45));
      expect(DietPlanGoalCalc.maxLossFor(45), 15);
    });

    test('onboarding selection builds a user with the plan applied for a lose goal only', () {
      final mask =
          UserDataMaskEntity(
              gender: UserGenderSelectionEntity.genderMale,
              birthday: DateTime(1990, 1, 1),
              height: 180,
              weight: 80,
              activity: UserActivitySelectionEntity.lowActive,
              goal: UserGoalSelectionEntity.loseWeight,
            )
            ..lossKg = 10
            ..paceKgPerWeek = 0.75;
      final lose = mask.toUserEntity()!;
      expect(lose.targetWeightKg, 70);
      expect(lose.weeklyRatePct, closeTo(0.75 / 80 * 100, 1e-9));

      mask.goal = UserGoalSelectionEntity.maintainWeight;
      final maintain = mask.toUserEntity()!;
      expect(maintain.targetWeightKg, isNull);
      expect(maintain.weeklyRatePct, isNull);
    });

    test('without a pick the kilos default to the gap to a typed target weight, else 5', () {
      final mask = UserDataMaskEntity(weight: 80, goal: UserGoalSelectionEntity.loseWeight);
      expect(mask.effectiveLossKg, 5);
      mask.targetWeight = 72;
      expect(mask.effectiveLossKg, 8);
      mask.lossKg = 12;
      expect(mask.effectiveLossKg, 12);
    });
  });
}
