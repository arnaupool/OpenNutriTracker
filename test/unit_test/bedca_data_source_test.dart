import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/bedca_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bedca/bedca_food_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/home/domain/entity/shared_meal_payload.dart';

// BEDCA (Base de Datos Española de Composición de Alimentos, AESAN) ships
// with the app as a bundled asset and is searched locally, so Spanish
// generic foods ("lentejas", "plátano") show up in the Food tab with their
// Spanish names and without network.
void main() {
  final sample = jsonEncode({
    'foods': [
      {
        'id': 1,
        'es': 'Lentejas, secas',
        'en': 'Lentil, dried',
        'n': {'kcal': 314.1, 'carb': 40.6, 'fat': 1.8, 'prot': 23.8, 'fib': 13.7, 'sat': 0.25, 'na': 7, 'fe': 7.1},
      },
      {
        'id': 2,
        'es': 'Lentejas con chorizo, guiso',
        'en': 'Lentil stew with chorizo',
        'n': {'kcal': 120, 'carb': 12, 'fat': 4.5, 'prot': 7},
      },
      {
        'id': 3,
        'es': 'Plátano',
        'en': 'Banana',
        'n': {'kcal': 94.2, 'carb': 20, 'fat': 0.27, 'prot': 1.2, 'sug': 18.1},
      },
      {
        'id': 4,
        'es': 'Empanada de atún',
        'en': 'Tuna pie',
        'n': {'kcal': 285, 'carb': 27, 'fat': 15, 'prot': 10},
      },
      {
        'id': 5,
        'es': 'Pan blanco',
        'en': 'Bread, white',
        'n': {'kcal': 261, 'carb': 51.5, 'fat': 1.6, 'prot': 8.5},
      },
      {
        'id': 6,
        'es': 'Piña',
        'en': 'Pineapple',
        'n': {'kcal': 50, 'carb': 11.5, 'fat': 0.1, 'prot': 0.5},
      },
    ],
  });

  late BedcaDataSource dataSource;

  setUp(() => dataSource = BedcaDataSource(loader: () async => sample));

  List<String> names(List<BedcaFoodDTO> foods) => foods.map((f) => f.nameEs).toList();

  group('BedcaDataSource.search', () {
    test('ranks the food whose name starts with the query first', () async {
      expect(names(await dataSource.search('lentejas')), ['Lentejas, secas', 'Lentejas con chorizo, guiso']);
    });

    test('ignores accents and case', () async {
      expect(names(await dataSource.search('PLATANO')), ['Plátano']);
      expect(names(await dataSource.search('pina')), ['Piña']);
    });

    test('every word of the query must match the start of a word', () async {
      expect(names(await dataSource.search('lentejas chorizo')), ['Lentejas con chorizo, guiso']);
      // "pan" must not match the middle of "empanada".
      expect(names(await dataSource.search('pan')), ['Pan blanco']);
    });

    test('a plural query finds the singular BEDCA name', () async {
      expect(names(await dataSource.search('platanos')), ['Plátano']);
      expect(names(await dataSource.search('panes')), ['Pan blanco']);
    });

    test('also matches the English name, after Spanish matches', () async {
      expect(names(await dataSource.search('banana')), ['Plátano']);
    });

    test('blank query returns nothing', () async {
      expect(await dataSource.search('   '), isEmpty);
    });

    test('loads the asset once', () async {
      var loads = 0;
      final counted = BedcaDataSource(loader: () async {
        loads++;
        return sample;
      });
      await counted.search('pan');
      await counted.search('lentejas');
      expect(loads, 1);
    });
  });

  group('MealEntity.fromBedcaFood', () {
    test('maps nutrients per 100 g and logs by weight', () async {
      final food = (await dataSource.search('lentejas secas')).single;
      final meal = MealEntity.fromBedcaFood(food);
      expect(meal.code, 'bedca-1');
      expect(meal.name, 'Lentejas, secas');
      expect(meal.source, MealSourceEntity.bedca);
      expect(meal.mealUnit, 'g/ml');
      expect(meal.servingQuantity, isNull);
      expect(meal.detailed, isTrue);
      final n = meal.nutriments;
      expect(n.energyKcal100, 314.1);
      expect(n.carbohydrates100, 40.6);
      expect(n.fat100, 1.8);
      expect(n.proteins100, 23.8);
      expect(n.fiber100, 13.7);
      expect(n.saturatedFat100, 0.25);
      expect(n.sodium100, 7);
      expect(n.iron100, 7.1);
      expect(n.sugars100, isNull);
    });

    test('source survives the Hive round trip', () async {
      final meal = MealEntity.fromBedcaFood((await dataSource.search('platano')).single);
      final back = MealEntity.fromMealDBO(MealDBO.fromMealEntity(meal));
      expect(back.source, MealSourceEntity.bedca);
      expect(back.nutriments.sugars100, 18.1);
    });
    test('a shared BEDCA item keeps its source and code', () {
      const item = SharedMealItem(
        name: 'Lentejas, secas',
        brands: 'BEDCA',
        unit: 'g',
        amount: 80,
        energyKcal100: 314.1,
        carbohydrates100: 40.6,
        fat100: 1.8,
        proteins100: 23.8,
        sugars100: null,
        saturatedFat100: 0.25,
        fiber100: 13.7,
        thumbnailImageUrl: null,
        mainImageUrl: null,
        source: MealSourceEntity.bedca,
        code: 'bedca-1',
      );
      final back = SharedMealItem.fromArray(item.toArray());
      expect(back.source, MealSourceEntity.bedca);
      expect(back.toMealEntity().code, 'bedca-1');
      expect(back.toMealEntity().nutriments.energyKcal100, 314.1);
    });
  });
  // The shipped asset itself (tool/bedca/build_bedca_asset.py output).
  group('bundled BEDCA asset', () {
    final asset = BedcaDataSource(loader: () async => File('assets/bedca/bedca_foods.json').readAsString());

    test('has the published foods, each with energy', () async {
      final json = jsonDecode(File('assets/bedca/bedca_foods.json').readAsStringSync()) as Map<String, dynamic>;
      final foods = (json['foods'] as List).map((f) => BedcaFoodDTO.fromJson(f as Map<String, dynamic>)).toList();
      expect(foods.length, greaterThan(900));
      expect(json['source'], contains('AESAN/BEDCA'));
      for (final f in foods) {
        expect(f[BedcaConst.kcal], isNotNull, reason: f.nameEs);
      }
    });

    test('energy agrees with the macronutrients (inconsistent entries are left out)', () async {
      final json = jsonDecode(File('assets/bedca/bedca_foods.json').readAsStringSync()) as Map<String, dynamic>;
      for (final f in (json['foods'] as List).map((f) => BedcaFoodDTO.fromJson(f as Map<String, dynamic>))) {
        final carb = f[BedcaConst.carbs], fat = f[BedcaConst.fat], prot = f[BedcaConst.protein];
        if (carb == null || fat == null || prot == null) continue;
        final kcal = f[BedcaConst.kcal]!;
        // Alcoholic drinks get the rest of their energy from ethanol.
        final estimate = 4 * carb + 9 * fat + 4 * prot + 2 * (f[BedcaConst.fiber] ?? 0);
        if (estimate < kcal) continue;
        expect((estimate - kcal).abs(), lessThanOrEqualTo(kcal * 0.2 > 25 ? kcal * 0.2 : 25), reason: f.nameEs);
      }
    });

    test('"lentejas" finds raw dried lentils with plausible values', () async {
      final results = await asset.search('lentejas');
      expect(results.every((f) => f.nameEs.startsWith('Lenteja')), isTrue);
      final lentils = results.firstWhere((f) => f.nameEs == 'Lenteja, seca, cruda');
      expect(lentils.nameEs, 'Lenteja, seca, cruda');
      final meal = MealEntity.fromBedcaFood(lentils);
      expect(meal.nutriments.energyKcal100, closeTo(309, 1));
      expect(meal.nutriments.proteins100, closeTo(24.8, 0.1));
    });

    test('mislabelled boiled foods with dry-food values are not offered', () async {
      expect(names(await asset.search('arroz hervido')), isNot(contains('Arroz, hervido')));
      expect(names(await asset.search('lenteja hervida')), isNot(contains('Lenteja, hervida')));
    });
  });
}
