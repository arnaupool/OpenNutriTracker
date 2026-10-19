import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';

class GetMacroGoalUsecase {
  final ConfigRepository _configRepository;
  final UserRepository _userRepository;

  GetMacroGoalUsecase(this._configRepository, this._userRepository);

  Future<double> getCarbsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    if (_hasManualOverride(config)) {
      return MacroCalc.getTotalCarbsGoal(
        totalCalorieGoal,
        userCarbsGoal: config.userCarbGoalPct,
      );
    }
    return (await _dynamicMacros(totalCalorieGoal)).carbG;
  }

  Future<double> getFatsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    if (_hasManualOverride(config)) {
      return MacroCalc.getTotalFatsGoal(
        totalCalorieGoal,
        userFatsGoal: config.userFatGoalPct,
      );
    }
    return (await _dynamicMacros(totalCalorieGoal)).fatG;
  }

  Future<double> getProteinsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    if (_hasManualOverride(config)) {
      return MacroCalc.getTotalProteinsGoal(
        totalCalorieGoal,
        userProteinsGoal: config.userProteinGoalPct,
      );
    }
    return (await _dynamicMacros(totalCalorieGoal)).proteinG;
  }

  /// Someone who has hand-set *any* of the three percentage splits in
  /// Settings → Macro Split gets the old fixed-percentage system for all
  /// three — protein-first is a single coherent 3-way split, and mixing
  /// it with a fixed fraction on just one macro wouldn't sum to the
  /// calorie goal correctly.
  bool _hasManualOverride(ConfigEntity config) =>
      config.userCarbGoalPct != null ||
      config.userFatGoalPct != null ||
      config.userProteinGoalPct != null;

  Future<MacroBreakdown> _dynamicMacros(double totalCalorieGoal) async {
    final user = await _userRepository.getUserData();
    return MacroDynamicCalc.calculateMacros(
      totalKcalGoal: totalCalorieGoal,
      weightKg: user.weightKG,
      heightCm: user.heightCM,
      proteinGPerKg: MacroDynamicCalc.defaultProteinGPerKg,
      isWeightLossGoal: user.goal == UserWeightGoalEntity.loseWeight,
    );
  }
}
