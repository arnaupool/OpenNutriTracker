import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_word_response_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

// Generic-food search now goes straight to the USDA FoodData Central API
// (https://api.nal.usda.gov/fdc/v1/foods/search) instead of the Supabase
// mirror. The fixture is a trimmed real response (2026-10-21): one
// Foundation food, which reports energy as Atwater factors (nutrientId
// 2047/2048), and one SR Legacy food, which reports plain Energy (1008) and
// "Sugars, total including NLEA" (2000). Each nutrient carries its
// nutrientId, its nutrientNumber and its value.
void main() {
  final json = jsonDecode(File('test/fixture/fdc_search_response.json').readAsStringSync()) as Map<String, dynamic>;
  final foods = FDCWordResponseDTO.fromJson(json).foods.map(MealEntity.fromFDCFood).toList();

  test('Foundation food: Atwater-specific energy, macros and micros per 100 g', () {
    final chicken = foods.firstWhere((m) => m.code == '2646170');
    final n = chicken.nutriments;
    expect(chicken.name, 'Chicken, breast, boneless, skinless, raw');
    expect(n.energyKcal100, 112);
    expect(n.proteins100, 22.5);
    expect(n.fat100, 1.93);
    expect(n.carbohydrates100, 0);
    expect(n.saturatedFat100, 0.349);
    expect(n.sodium100, 65.8);
    expect(n.iron100, 0.354);
  });

  test('SR Legacy food: plain energy and NLEA total sugars', () {
    final rice = foods.firstWhere((m) => m.code == '168877');
    final n = rice.nutriments;
    expect(n.energyKcal100, 365);
    expect(n.carbohydrates100, 80);
    expect(n.proteins100, 7.13);
    expect(n.fat100, 0.66);
    expect(n.sugars100, 0.12);
    expect(n.fiber100, 1.3);
  });

  test('generic foods are logged by weight (g/ml) when FDC gives no serving', () {
    for (final m in foods) {
      expect(m.mealUnit, 'g/ml');
      expect(m.source, MealSourceEntity.fdc);
    }
  });
}
