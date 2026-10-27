import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/low_kcal_warning_card.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/diet_plan/presentation/diet_plan_format.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class OnboardingOverviewPageBody extends StatelessWidget {
  final String calorieGoalDayString;
  final String carbsGoalString;
  final String fatGoalString;
  final String proteinGoalString;
  final Function(bool active) setButtonActive;
  final double? totalKcalCalculated;
  final bool showLowKcalWarning;
  final double lowKcalWarningThreshold;

  /// End date and length of the diet plan the user just set up; null when
  /// the goal is not "lose weight".
  final DateTime? planEnd;
  final int planDays;
  final bool showCountdown;
  final ValueChanged<bool>? onShowCountdownChanged;

  /// A lower pace (kg/week) that keeps the goal above the kcal floor, and
  /// the callback that applies it.
  final double? suggestedPace;
  final VoidCallback? onApplySuggestedPace;

  const OnboardingOverviewPageBody({
    super.key,
    required this.setButtonActive,
    this.totalKcalCalculated,
    required this.calorieGoalDayString,
    required this.carbsGoalString,
    required this.fatGoalString,
    required this.proteinGoalString,
    this.showLowKcalWarning = false,
    this.lowKcalWarningThreshold = 0,
    this.planEnd,
    this.planDays = 0,
    this.showCountdown = true,
    this.onShowCountdownChanged,
    this.suggestedPace,
    this.onApplySuggestedPace,
  });

  @override
  Widget build(BuildContext context) {
    // #177: Stored calorie goal is always in kcal; only the displayed
    // number and unit-suffix change when the user prefers kJ.
    final usesKilojoules = context.watch<EnergyUnitProvider>().usesKilojoules;
    final parsedKcalGoal = double.tryParse(calorieGoalDayString) ?? 0;
    final displayGoalString = usesKilojoules
        ? UnitCalc.kcalToKj(parsedKcalGoal).round().toString()
        : calorieGoalDayString;
    final perDayLabel = usesKilojoules
        ? S.of(context).onboardingKjPerDayLabel
        : S.of(context).onboardingKcalPerDayLabel;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).onboardingOverviewLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32.0),
          Text(
            S.of(context).onboardingYourGoalLabel,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8.0),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayGoalString,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  perDayLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          if (showLowKcalWarning) ...[
            const SizedBox(height: 24.0),
            LowKcalWarningCard(
              thresholdKcal: lowKcalWarningThreshold,
              margin: EdgeInsets.zero,
            ),
            if (planEnd != null) ...[
              const SizedBox(height: 8.0),
              Text(
                S.of(context).onboardingPlanFloorSlower,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (suggestedPace != null) ...[
              const SizedBox(height: 8.0),
              Text(
                S.of(context).onboardingPlanFloorSuggestion(DietPlanFormat.pace(context, suggestedPace!)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  identifier: 'onboarding-plan-apply-pace',
                  child: TextButton(
                    onPressed: onApplySuggestedPace,
                    child: Text(
                      S.of(context).onboardingPlanFloorApply(DietPlanFormat.pace(context, suggestedPace!)),
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (planEnd != null) ...[
            const SizedBox(height: 24.0),
            Text(
              S.of(context).onboardingPlanReachDate(DietPlanFormat.date(planEnd!), planDays.toString()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Semantics(
              identifier: 'onboarding-plan-countdown-switch',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(S.of(context).dietPlanShowCountdown),
                value: showCountdown,
                onChanged: onShowCountdownChanged,
              ),
            ),
          ],
          const SizedBox(height: 32.0),
          Text(
            S.of(context).onboardingYourMacrosGoalLabel,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16.0),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$carbsGoalString g',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  S.of(context).carbsLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '$fatGoalString g',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                Text(
                  S.of(context).fatLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '$proteinGoalString g',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                Text(
                  S.of(context).proteinLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SourcesScreen()),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(S.of(context).settingsSourcesLabel),
            ),
          ),
        ],
      ),
    );
  }
}
