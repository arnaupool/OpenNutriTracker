import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/utils/bounds/ranges_const.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_goal_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_usecase.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_data_mask_entity.dart';

part 'onboarding_event.dart';

part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final userSelection = UserDataMaskEntity();
  final AddUserUsecase _addUserUsecase;
  final AddConfigUsecase _addConfigUsecase;

  final DietPlanUsecase? _dietPlanUsecase;

  OnboardingBloc(
    this._addUserUsecase,
    this._addConfigUsecase, [
    this._dietPlanUsecase,
  ]) : super(OnboardingInitialState()) {
    on<LoadOnboardingEvent>((event, emit) async {
      emit(OnboardingLoadingState());

      emit(OnboardingLoadedState());
    });
  }

  Future<void> saveOnboardingData(
    UserEntity userEntity,
    bool hasAcceptedDataCollection,
    bool usesImperialUnits,
  ) async {
    await _addUserUsecase.addUser(userEntity);
    await _addConfigUsecase.setConfigHasAcceptedAnonymousData(
      hasAcceptedDataCollection,
    );
    await _addConfigUsecase.setConfigUsesImperialUnits(usesImperialUnits);
    // A "lose weight" onboarding also creates the diet plan whose end date
    // the overview page showed.
    final kg = userSelection.effectiveLossKg;
    if (userSelection.isLoseGoal && kg != null) {
      await _dietPlanUsecase?.save(
        DietPlanUsecase.newAutoPlan(
          start: DateTime.now(),
          startWeightKg: userEntity.weightKG,
          kgToLose: kg,
          paceKgPerWeek: userSelection.paceKgPerWeek,
          showCountdown: userSelection.showCountdown,
        ),
      );
    }
  }

  /// The date the overview promises: today plus the plan's duration, or
  /// null when the goal is not "lose weight".
  ({DateTime end, int days})? getOverviewPlanEnd({DateTime? today}) {
    final kg = userSelection.effectiveLossKg;
    if (!userSelection.isLoseGoal || kg == null) return null;
    final start = DietPlanCalc.dateOnly(today ?? DateTime.now());
    final end = DietPlanCalc.autoEnd(start, kg, userSelection.paceKgPerWeek);
    return (end: end, days: DietPlanCalc.daysBetween(start, end));
  }

  /// A lower pace that keeps the goal above the kcal floor, when the
  /// chosen one does not.
  double? getOverviewSuggestedPace() {
    final userEntity = userSelection.toUserEntity();
    final kg = userSelection.effectiveLossKg;
    if (userEntity == null || kg == null) return null;
    return DietPlanGoalCalc.suggestedPace(
      userEntity,
      kgToLose: kg,
      currentPace: userSelection.paceKgPerWeek,
    );
  }

  /// The goal the app will actually use right after onboarding: the same
  /// static core goal GetKcalGoalUsecase starts the program with.
  double? getOverviewCalorieGoal() {
    final userEntity = userSelection.toUserEntity();
    if (userEntity == null) return null;
    return CalorieGoalCalc.applyRecommendedDailyKcalFloor(
      CalorieGoalCalc.getStaticCoreGoal(userEntity),
      userEntity,
    );
  }

  /// The protein-first split GetMacroGoalUsecase applies to that goal.
  MacroBreakdown? _overviewMacros() {
    final userEntity = userSelection.toUserEntity();
    final calorieGoal = getOverviewCalorieGoal();
    if (userEntity == null || calorieGoal == null) return null;
    return MacroDynamicCalc.calculateMacros(
      totalKcalGoal: calorieGoal,
      weightKg: userEntity.weightKG,
      heightCm: userEntity.heightCM,
      proteinGPerKg: MacroDynamicCalc.defaultProteinGPerKg,
      isWeightLossGoal: userEntity.goal == UserWeightGoalEntity.loseWeight,
    );
  }

  double? getOverviewCarbsGoal() => _overviewMacros()?.carbG;

  double? getOverviewFatGoal() => _overviewMacros()?.fatG;

  double? getOverviewProteinGoal() => _overviewMacros()?.proteinG;

  /// Whether the calorie goal computed for the current onboarding
  /// selection has dropped below the research-backed floor for the user's
  /// hormonal profile. Used by the overview page to decide whether to
  /// surface the soft low-kcal warning.
  bool isOverviewBelowRecommendedKcalFloor() {
    final userEntity = userSelection.toUserEntity();
    if (userEntity == null) return false;
    // The shown goal is already raised to the floor, so ask the engine
    // whether it had to.
    return DietPlanGoalCalc.goalFor(userEntity).floorApplied;
  }

  /// The kcal floor the overview warning quotes back to the user. Falls
  /// back to the lower (female-typical) bound when the selection isn't
  /// resolvable yet, so the displayed number is always a sensible default.
  double getOverviewRecommendedKcalFloor() {
    final userEntity = userSelection.toUserEntity();
    if (userEntity == null) return Ranges.minRecommendedDailyKcalFemale;
    return CalorieGoalCalc.recommendedDailyKcalFloor(
      gender: userEntity.gender,
      caloriesProfile: userEntity.caloriesProfile,
    );
  }
}
