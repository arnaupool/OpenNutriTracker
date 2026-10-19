import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/goal_rate_calc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// One sentence explaining which [GoalRateCalc.adjustment] phase today's
/// dynamic goal is in. Shared by Strategy's "Today's Target" card and
/// Home's Goal Progress card so both always say the same thing.
String goalExplanation(S s, UserEntity user, double trendWeightKg) {
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
      return s.strategyExplanationWithinBand;
    case GoalPhase.correcting:
      return s.strategyExplanationCorrecting(
        (trendWeightKg - user.targetWeightKg!).abs().toStringAsFixed(1),
        adjustment.adjustmentKcal.abs().round().toString(),
      );
    case GoalPhase.rate:
      final kcal = adjustment.adjustmentKcal.round();
      return s.strategyExplanationRate(
        formatRatePct(ratePct),
        '${kcal > 0 ? '+' : ''}$kcal',
      );
  }
}

/// "0.5", "0.75", "1": the rate without trailing zeros.
String formatRatePct(double ratePct) {
  final fixed = ratePct.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
