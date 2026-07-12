import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/macro_dynamic_calc.dart';

void main() {
  group('proteinGoalG', () {
    test('uses the given g/kg within range, no bonus for non-loss goals', () {
      final result = MacroDynamicCalc.proteinGoalG(
        weightKg: 80,
        proteinGPerKg: 1.8,
      );
      expect(result, closeTo(144.0, 0.001)); // 1.8 * 80
    });

    test('adds the +0.1 g/kg bonus for weight-loss goals', () {
      final result = MacroDynamicCalc.proteinGoalG(
        weightKg: 80,
        proteinGPerKg: 1.8,
        isWeightLossGoal: true,
      );
      expect(result, closeTo(152.0, 0.001)); // (1.8 + 0.1) * 80
    });

    test('clamps below the documented range up to 1.6 g/kg', () {
      final result = MacroDynamicCalc.proteinGoalG(
        weightKg: 80,
        proteinGPerKg: 1.0,
      );
      expect(result, closeTo(128.0, 0.001)); // 1.6 * 80
    });

    test('clamps above the documented range down to 2.2 g/kg', () {
      final result = MacroDynamicCalc.proteinGoalG(
        weightKg: 80,
        proteinGPerKg: 3.0,
      );
      expect(result, closeTo(176.0, 0.001)); // 2.2 * 80
    });
  });

  group('minimumFatG', () {
    test('180cm gives the handbook-style example of 45g', () {
      expect(MacroDynamicCalc.minimumFatG(180), closeTo(45.0, 0.001));
    });

    test('150cm exactly gives the base 30g', () {
      expect(MacroDynamicCalc.minimumFatG(150), closeTo(30.0, 0.001));
    });

    test('below 150cm floors at 30g rather than going lower', () {
      expect(MacroDynamicCalc.minimumFatG(140), 30.0);
    });

    test('200cm gives 55g', () {
      expect(MacroDynamicCalc.minimumFatG(200), closeTo(55.0, 0.001));
    });
  });

  group('calculateMacros (balanced program)', () {
    test('protein first, then an even balanced split of the remainder', () {
      // protein = (1.8+0.1)*80 = 152g -> 608 kcal
      // remaining = 2200 - 608 = 1592 kcal -> 796/796 fat/carb kcal
      // fat = 796/9 = 88.44g, carb = 796/4 = 199g
      // fat floor at 180cm is 45g, well below 88.44g -> no floor triggered.
      final result = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: 2200,
        weightKg: 80,
        heightCm: 180,
        proteinGPerKg: 1.8,
        isWeightLossGoal: true,
      );

      expect(result.proteinG, closeTo(152.0, 0.001));
      expect(result.fatG, closeTo(88.444, 0.01));
      expect(result.carbG, closeTo(199.0, 0.001));

      // carb should land within MacroFactor's documented 2-2.5x fat
      // (in grams) heuristic for the balanced program.
      final ratio = result.carbG / result.fatG;
      expect(ratio, greaterThanOrEqualTo(2.0));
      expect(ratio, lessThanOrEqualTo(2.5));
    });

    test('reconstructed calories match the total goal', () {
      final result = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: 2200,
        weightKg: 80,
        heightCm: 180,
        proteinGPerKg: 1.8,
        isWeightLossGoal: true,
      );

      final reconstructedKcal =
          result.proteinG * 4 + result.fatG * 9 + result.carbG * 4;

      expect(reconstructedKcal, closeTo(2200, 0.01));
    });

    test('fat floor overrides the balanced split when it would go too low', () {
      // protein = 1.6*50 = 80g -> 320 kcal
      // remaining = 1200 - 320 = 880 kcal -> even split gives fat = 440/9
      //   = 48.9g, but the 200cm fat floor is 55g, so the floor wins.
      final result = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: 1200,
        weightKg: 50,
        heightCm: 200,
        proteinGPerKg: 1.6,
      );

      expect(result.proteinG, closeTo(80.0, 0.001));
      expect(result.fatG, closeTo(55.0, 0.001)); // the floor, not 48.9
      expect(result.carbG, closeTo(96.25, 0.01));

      final reconstructedKcal =
          result.proteinG * 4 + result.fatG * 9 + result.carbG * 4;
      expect(reconstructedKcal, closeTo(1200, 0.01));
    });

    test('remaining calories never go negative when protein alone exceeds '
        'the total goal', () {
      final result = MacroDynamicCalc.calculateMacros(
        totalKcalGoal: 100,
        weightKg: 80,
        heightCm: 180,
        proteinGPerKg: 2.2,
        isWeightLossGoal: true,
      );

      expect(result.proteinG, closeTo(184.0, 0.001)); // (2.2+0.1)*80
      expect(result.fatG, greaterThanOrEqualTo(0.0));
      expect(result.carbG, greaterThanOrEqualTo(0.0));
    });
  });
}
