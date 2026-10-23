import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_ingredient_dbo.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/meal_plan/domain/meal_plan_calc.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

MealNutrimentsDBO _n(double kcal, double p, double c, double f) => MealNutrimentsDBO(
  energyKcal100: kcal,
  carbohydrates100: c,
  fat100: f,
  proteins100: p,
  sugars100: null,
  saturatedFat100: null,
  fiber100: null,
);

MealDBO _meal(String name, {String? code, MealSourceDBO source = MealSourceDBO.custom, MealNutrimentsDBO? n}) => MealDBO(
  code: code,
  name: name,
  brands: null,
  thumbnailImageUrl: null,
  mainImageUrl: null,
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: null,
  source: source,
  nutriments: n ?? _n(100, 10, 10, 2),
);

MealPlanEntryDBO _entry(String id, MealDBO meal, double grams, {DateTime? day, IntakeTypeDBO type = IntakeTypeDBO.lunch}) =>
    MealPlanEntryDBO(id: id, day: day ?? DateTime(2026, 10, 26), type: type, meal: meal, amount: grams, unit: 'g');

void main() {
  test('totals scale the per-100 g values by the planned grams', () {
    final totals = MealPlanCalc.totals([
      _entry('a', _meal('Rice', n: _n(130, 2.7, 28, 0.3)), 200),
      _entry('b', _meal('Chicken', n: _n(165, 31, 0, 3.6)), 150),
    ]);
    expect(totals.kcal, closeTo(260 + 247.5, 0.01));
    expect(totals.protein, closeTo(5.4 + 46.5, 0.01));
    expect(totals.carbs, closeTo(56, 0.01));
    expect(totals.fat, closeTo(0.6 + 5.4, 0.01));
  });

  test('shopping list breaks recipes into ingredients and adds up the same food', () {
    final recipe = RecipeDBO(
      id: 'r1',
      name: 'Paella',
      description: null,
      ingredients: [
        RecipeIngredientDBO(snapshotMeal: _meal('Rice'), amount: 400, unit: 'g', convertedAmountG: 400),
        RecipeIngredientDBO(snapshotMeal: _meal('Chicken'), amount: 600, unit: 'g', convertedAmountG: 600),
      ],
      totalWeightG: 1000,
      aggregatedNutrimentsPer100: _n(150, 12, 15, 4),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      servingsCount: 4,
      tags: null,
      imagePath: null,
    );
    final items = MealPlanCalc.shoppingList(
      [
        // Half the recipe: 200 g rice, 300 g chicken.
        _entry('a', _meal('Paella', code: 'r1', source: MealSourceDBO.recipe), 500),
        _entry('b', _meal('rice'), 100),
        _entry('c', _meal('Yogurt'), 125),
      ],
      {'r1': recipe},
    );
    expect(items.map((i) => (i.name, i.amount.round(), i.unit)), [
      ('Chicken', 300, 'g'),
      ('Rice', 300, 'g'),
      ('Yogurt', 125, 'g'),
    ]);
  });

  test('a planned recipe that was deleted is bought as itself', () {
    final items = MealPlanCalc.shoppingList([
      _entry('a', _meal('Gone recipe', code: 'missing', source: MealSourceDBO.recipe), 300),
    ], {});
    expect(items.single.name, 'Gone recipe');
    expect(items.single.amount, 300);
  });

  test('entries round-trip through JSON for sync', () {
    final entry = _entry('a', _meal('Rice'), 180).copyWith(loggedAt: DateTime(2026, 10, 26, 14));
    final back = MealPlanEntryDBO.fromJson(jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>);
    expect(back.id, 'a');
    expect(back.type, IntakeTypeDBO.lunch);
    expect(back.meal.name, 'Rice');
    expect(back.amount, 180);
    expect(back.loggedAt, DateTime(2026, 10, 26, 14));
  });

  test('the Hive adapter stores and reads entries; the data source filters by day', () async {
    Hive.registerAdapters();
    if (!Hive.isAdapterRegistered(MealPlanEntryDBO.hiveTypeId)) Hive.registerAdapter(MealPlanEntryDBOAdapter());
    final box = await Hive.openBox<MealPlanEntryDBO>('plan-test', bytes: Uint8List(0));
    final source = MealPlanDataSource(box);
    await source.save(_entry('mon', _meal('Rice'), 100, day: DateTime(2026, 10, 26)));
    await source.save(_entry('sun', _meal('Rice'), 100, day: DateTime(2026, 11, 1)));
    await source.save(_entry('next', _meal('Rice'), 100, day: DateTime(2026, 11, 2)));
    final week = source.entriesBetween(DateTime(2026, 10, 26), DateTime(2026, 11, 1));
    expect(week.map((e) => e.id), unorderedEquals(['mon', 'sun']));
    expect(box.get('mon')!.meal.nutriments.energyKcal100, 100);
    await source.delete('mon');
    expect(source.entriesBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 26)), isEmpty);
  });
}
