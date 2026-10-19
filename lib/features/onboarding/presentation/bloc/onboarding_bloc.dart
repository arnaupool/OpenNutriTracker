import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/utils/bounds/ranges_const.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_data_mask_entity.dart';

part 'onboarding_event.dart';

part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final userSelection = UserDataMaskEntity();
  final AddUserUsecase _addUserUsecase;
  final AddConfigUsecase _addConfigUsecase;

  OnboardingBloc(this._addUserUsecase, this._addConfigUsecase)
      : super(OnboardingInitialState()) {
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
  }

  /// The goal the app will actually use right after onboarding: the same
  /// static core goal GetKcalGoalUsecase starts the program with.
  double? getOverviewCalorieGoal() {
    final userEntity = userSelection.toUserEntity();
    if (userEntity == null) return null;
    return CalorieGoalCalc.getStaticCoreGoal(userEntity);
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
    final calorieGoal = getOverviewCalorieGoal();
    if (userEntity == null || calorieGoal == null) return false;
    return CalorieGoalCalc.isBelowRecommendedDailyKcalFloor(
      goalKcal: calorieGoal,
      gender: userEntity.gender,
      caloriesProfile: userEntity.caloriesProfile,
    );
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
