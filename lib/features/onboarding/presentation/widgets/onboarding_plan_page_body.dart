import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';
import 'package:opennutritracker/features/diet_plan/presentation/diet_plan_format.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Onboarding step after the goal: how many kg to lose and at what pace.
/// Only meaningful for a "lose weight" goal; other goals see a short note.
/// Stateless: the parent keeps the values in the onboarding selection.
class OnboardingPlanPageBody extends StatelessWidget {
  final bool isLoseGoal;
  final double lossKg;
  final double maxLossKg;
  final double paceKgPerWeek;
  final bool usesImperialUnits;
  final void Function(double lossKg) onLossChanged;
  final void Function(double paceKgPerWeek) onPaceChanged;

  const OnboardingPlanPageBody({
    super.key,
    required this.isLoseGoal,
    required this.lossKg,
    required this.maxLossKg,
    required this.paceKgPerWeek,
    required this.onLossChanged,
    required this.onPaceChanged,
    this.usesImperialUnits = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    if (!isLoseGoal) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.onboardingPlanTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16.0),
            Text(s.onboardingPlanOnlyForLoss, style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }
    final loss = lossKg.clamp(DietPlanCalc.minLossKg, maxLossKg).toDouble();
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.onboardingPlanTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24.0),
            Text(s.onboardingPlanLossQuestion, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  identifier: 'onboarding-plan-loss-minus',
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: loss > DietPlanCalc.minLossKg
                        ? () => onLossChanged(loss - DietPlanCalc.lossStepKg)
                        : null,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${DietPlanFormat.number(context, loss)} ${s.kgLabel}',
                      style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    if (usesImperialUnits)
                      Text(
                        '${DietPlanFormat.number(context, UnitCalc.kgToLbs(loss))} ${s.lbsLabel}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
                Semantics(
                  identifier: 'onboarding-plan-loss-plus',
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: loss < maxLossKg ? () => onLossChanged(loss + DietPlanCalc.lossStepKg) : null,
                  ),
                ),
              ],
            ),
            Semantics(
              identifier: 'onboarding-plan-loss-slider',
              child: Slider(
                value: loss,
                min: DietPlanCalc.minLossKg,
                max: maxLossKg > DietPlanCalc.minLossKg ? maxLossKg : DietPlanCalc.minLossKg + DietPlanCalc.lossStepKg,
                divisions: maxLossKg > DietPlanCalc.minLossKg
                    ? ((maxLossKg - DietPlanCalc.minLossKg) / DietPlanCalc.lossStepKg).round()
                    : 1,
                label: DietPlanFormat.number(context, loss),
                onChanged: (v) => onLossChanged(v),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(s.onboardingPlanPaceQuestion, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8.0),
            Semantics(
              identifier: 'onboarding-plan-pace',
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final p in DietPlanCalc.paceOptions)
                    ButtonSegment<double>(value: p, label: Text(s.dietPlanPaceOption(DietPlanFormat.pace(context, p)))),
                ],
                selected: {paceKgPerWeek},
                onSelectionChanged: (selection) => onPaceChanged(selection.first),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(s.onboardingPlanPaceHint, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
