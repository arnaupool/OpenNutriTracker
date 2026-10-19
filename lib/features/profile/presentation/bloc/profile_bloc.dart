import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/user_bmi_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/bmi_calc.dart';
import 'package:opennutritracker/core/utils/calc/tdee_dynamic_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_interpolation_calc.dart';
import 'package:opennutritracker/core/utils/calc/weight_trend_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/utils/profile_display_format.dart';

part 'profile_event.dart';

part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserUsecase _getUserUsecase;
  final AddUserUsecase _addUserUsecase;
  final AddTrackedDayUsecase _addTrackedDayUsecase;
  final GetConfigUsecase _getConfigUsecase;
  final GetKcalGoalUsecase _getKcalGoalUsecase;

  ProfileBloc(
    this._getUserUsecase,
    this._addUserUsecase,
    this._addTrackedDayUsecase,
    this._getConfigUsecase,
    this._getKcalGoalUsecase,
  ) : super(ProfileInitial()) {
    on<LoadProfileEvent>((event, emit) async {
      emit(ProfileLoadingState());

      final user = await _getUserUsecase.getUserData();
      final userBMIValue = BMICalc.getBMI(user);
      final userBMIEntity = UserBMIEntity(
        bmiValue: userBMIValue,
        nutritionalStatus: BMICalc.getNutritionalStatus(userBMIValue),
      );
      final userConfig = await _getConfigUsecase.getConfig();
      final trendWeightKg = await _trendWeightKg();

      emit(
        ProfileLoadedState(
          userBMI: userBMIEntity,
          userEntity: user,
          usesImperialUnits: userConfig.usesImperialUnits,
          effectiveWaterGoalMl: userConfig.effectiveDailyWaterGoalMl(
            user.gender,
            caloriesProfile: user.caloriesProfile,
          ),
          trendWeightKg: trendWeightKg,
        ),
      );
    });
  }

  Future<double?> _trendWeightKg() async {
    if (!locator.isRegistered<GetWeightLogUsecase>()) return null;
    final entries = await locator<GetWeightLogUsecase>().getAllEntries();
    final trend = WeightTrendCalc.computeTrend(
      WeightInterpolationCalc.fillGaps(entries),
    );
    if (trend.length < TdeeDynamicCalc.minTrendPointsForDynamic) return null;
    return trend.last.trendWeightKg;
  }

  Future<UserEntity> getUser() => _getUserUsecase.getUserData();

  /// Persist the opt-in calorie-deficit taper. Toggling re-runs the
  /// kcal-goal calc on today's tracked day so the saved goal reflects
  /// the new value immediately rather than waiting for the next day.
  Future<void> setCaloriesTaperEnabled(bool enabled) async {
    final user = await _getUserUsecase.getUserData();
    user.caloriesTaperEnabled = enabled;
    await updateUser(user);
  }

  Future<void> updateUser(UserEntity userEntity) async {
    // FM-15: the weekly check-in state lives on the user record but is
    // owned by GetKcalGoalUsecase; keep the stored copy so an entity loaded
    // before a check-in can't roll it back.
    final stored = await _getUserUsecase.getUserData();
    userEntity
      ..checkInCoreGoalKcal = stored.checkInCoreGoalKcal
      ..lastCheckInDay = stored.lastCheckInDay
      ..checkInWeekday = stored.checkInWeekday;

    // Update user in DB
    await _addUserUsecase.addUser(userEntity);

    // A new goal or target weight is a new MacroFactor program, set from
    // the current expenditure right away (help.macrofactorapp.com art.
    // 205). A rate change waits for the next check-in (art. 222).
    if (stored.goal != userEntity.goal ||
        stored.targetWeightKg != userEntity.targetWeightKg) {
      await _getKcalGoalUsecase.restartProgram();
    }

    // Update Tracked Day
    await _updateTrackedDayCalorieGoal(userEntity, DateTime.now());

    // Refresh Profile
    add(LoadProfileEvent());
    // Refresh Home Page
    locator<HomeBloc>().add(const LoadItemsEvent());
    // Refresh Diary Page
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }

  Future<void> _updateTrackedDayCalorieGoal(
    UserEntity user,
    DateTime day,
  ) async {
    final hasTrackedDay = await _addTrackedDayUsecase.hasTrackedDay(day);
    if (hasTrackedDay) {
      final totalKcalGoal = await _getKcalGoalUsecase.getKcalGoal(
        userEntity: user,
      );

      await _addTrackedDayUsecase.updateDayCalorieGoal(day, totalKcalGoal);
    }
  }

  /// Returns the user's height in cm or ft/in based on the user's config
  String getDisplayHeight(UserEntity user, bool usesImperialUnits) {
    if (usesImperialUnits) {
      // Convert cm to feet and inches
      return UnitCalc.cmToFeet(user.heightCM).toStringAsFixed(1);
    } else {
      return user.heightCM.roundToDouble().toStringAsFixed(0);
    }
  }

  /// Returns the user's weight in kg or lbs based on the user's config
  String getDisplayWeight(UserEntity user, bool usesImperialUnits) {
    final displayWeight = usesImperialUnits
        ? UnitCalc.kgToLbs(user.weightKG)
        : user.weightKG;

    return formatProfileWeight(displayWeight);
  }
}
