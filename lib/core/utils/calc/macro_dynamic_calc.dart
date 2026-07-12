/// Protein/fat/carb breakdown in grams for a total calorie goal.
typedef MacroBreakdown = ({double proteinG, double fatG, double carbG});

/// Which non-protein calories get skewed toward. Only [balanced] has a
/// precise numeric rule in the sources this fork is built from (see the
/// "Fase Motor" plan) — High-Carb/Low-Fat, Low-Carb/High-Fat, and Keto are
/// described only qualitatively by MacroFactor, so they aren't implemented
/// here yet rather than guessing at unstated ratios.
enum MacroProgram { balanced }

class MacroDynamicCalc {
  static const double kcalPerGramProtein = 4;
  static const double kcalPerGramCarb = 4;
  static const double kcalPerGramFat = 9;

  /// Protein range MacroFactor documents, in g/kg body weight.
  static const double proteinLowGPerKg = 1.6;
  static const double proteinHighGPerKg = 2.2;

  /// Extra protein MacroFactor adds as "muscle-loss insurance" when the
  /// goal is weight loss.
  static const double proteinWeightLossBonusGPerKg = 0.1;

  /// Protein target in grams: [proteinGPerKg] × body weight, clamped to
  /// MacroFactor's documented 1.6–2.2 g/kg range, plus the +0.1 g/kg
  /// bonus when [isWeightLossGoal].
  static double proteinGoalG({
    required double weightKg,
    required double proteinGPerKg,
    bool isWeightLossGoal = false,
  }) {
    final clamped = proteinGPerKg.clamp(proteinLowGPerKg, proteinHighGPerKg);
    final bonus = isWeightLossGoal ? proteinWeightLossBonusGPerKg : 0.0;
    return (clamped + bonus) * weightKg;
  }

  /// Minimum fat floor MacroFactor documents:
  /// `((height_cm - 150) * 0.5) + 30`, floored at 30g for heights below
  /// 150cm.
  static double minimumFatG(double heightCm) {
    if (heightCm < 150) return 30.0;
    return ((heightCm - 150) * 0.5) + 30.0;
  }

  /// Splits [totalKcalGoal] into protein/fat/carb grams. Protein is
  /// computed first from body weight (see [proteinGoalG]); the remaining
  /// calories are split between fat and carb according to [program],
  /// with fat never going below [minimumFatG] regardless of what the
  /// program's split alone would produce — carb absorbs the difference.
  static MacroBreakdown calculateMacros({
    required double totalKcalGoal,
    required double weightKg,
    required double heightCm,
    required double proteinGPerKg,
    bool isWeightLossGoal = false,
    MacroProgram program = MacroProgram.balanced,
  }) {
    final proteinG = proteinGoalG(
      weightKg: weightKg,
      proteinGPerKg: proteinGPerKg,
      isWeightLossGoal: isWeightLossGoal,
    );
    final proteinKcal = proteinG * kcalPerGramProtein;
    final remainingRaw = totalKcalGoal - proteinKcal;
    final remainingKcal = remainingRaw < 0 ? 0.0 : remainingRaw;

    switch (program) {
      case MacroProgram.balanced:
        // 50/50 kcal split between fat and carb. Since fat is
        // kcalPerGramFat/kcalPerGramCarb = 2.25x more calorie-dense than
        // carb, an even kcal split naturally produces carb grams ~2.25x
        // fat grams — matching MacroFactor's documented "carb ≈ 2 to 2.5
        // × fat, in grams" heuristic for this program.
        var fatG = (remainingKcal / 2) / kcalPerGramFat;
        var carbG = (remainingKcal / 2) / kcalPerGramCarb;

        final fatFloor = minimumFatG(heightCm);
        if (fatG < fatFloor) {
          final fatKcal = fatFloor * kcalPerGramFat;
          final carbKcalRaw = remainingKcal - fatKcal;
          final carbKcal = carbKcalRaw < 0 ? 0.0 : carbKcalRaw;
          fatG = fatFloor;
          carbG = carbKcal / kcalPerGramCarb;
        }

        return (proteinG: proteinG, fatG: fatG, carbG: carbG);
    }
  }
}
