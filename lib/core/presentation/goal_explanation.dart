import 'package:flutter/widgets.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/dynamic_maintenance_calc.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// One sentence explaining which [GoalRateCalc.adjustment] phase today's
/// dynamic goal is in, in the user's energy and weight units. Shared by
/// Strategy's "Today's Target" card and Home's Goal Progress card so both
/// always say the same thing. Call from `build` (it watches the energy
/// unit).
String goalExplanation(
  BuildContext context,
  UserEntity user,
  double trendWeightKg, {
  required bool usesImperialUnits,
}) {
  final s = S.of(context);
  String weight(double kg) => usesImperialUnits
      ? '${UnitCalc.kgToLbs(kg).toStringAsFixed(1)} ${s.lbsLabel}'
      : '${kg.toStringAsFixed(1)} ${s.kgLabel}';
  String energy(double kcal) => EnergyDisplay.formatWithUnit(context, kcal);

  final ratePct = GoalRateCalc.effectiveRatePct(user);
  final adjustment = GoalRateCalc.adjustment(
    goal: user.goal,
    trendWeightKg: trendWeightKg,
    targetWeightKg: user.targetWeightKg,
    ratePct: ratePct,
  );
  switch (adjustment.phase) {
    case GoalPhase.maintaining:
      return s.strategyExplanationMaintaining;
    case GoalPhase.withinBand:
      return s.strategyExplanationWithinBand(
        weight(DynamicMaintenanceCalc.maintenanceBandKg),
      );
    case GoalPhase.correcting:
      return s.strategyExplanationCorrecting(
        weight((trendWeightKg - user.targetWeightKg!).abs()),
        energy(adjustment.adjustmentKcal.abs()),
      );
    case GoalPhase.rate:
      final sign = adjustment.adjustmentKcal > 0 ? '+' : '-';
      return s.strategyExplanationRate(
        formatRatePct(ratePct),
        '$sign${energy(adjustment.adjustmentKcal.abs())}',
      );
  }
}

/// "0.5", "0.75", "1": the rate without trailing zeros.
String formatRatePct(double ratePct) {
  final fixed = ratePct.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
