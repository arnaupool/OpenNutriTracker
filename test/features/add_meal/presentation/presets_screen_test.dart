import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/merge_custom_meals_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeCustomMealDataSource extends Fake implements CustomMealDataSource {
  final List<MealDBO> meals;
  _FakeCustomMealDataSource(this.meals);

  @override
  List<MealDBO> getAllCustomMeals() => meals;
}

// Never exercised by the LoadCustomMealsEvent path this screen relies on —
// only by Delete/Merge, which these tests don't trigger.
class _FakeGetIntakeUsecase extends Fake implements GetIntakeUsecase {}

class _FakeDeleteIntakeUsecase extends Fake implements DeleteIntakeUsecase {}

class _FakeAddTrackedDayUsecase extends Fake implements AddTrackedDayUsecase {}

class _FakeMergeCustomMealsUseCase extends Fake
    implements MergeCustomMealsUseCase {}

class _FakeRecipeRepository extends Fake implements RecipeRepository {
  List<RecipeEntity> recipes = const [];

  @override
  List<RecipeEntity> getAllRecipes() => recipes;
}

class _FakeGetConfigUsecase extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.dark);
}

MealEntity _customMeal(String name) => MealEntity(
  code: name,
  name: name,
  url: null,
  mealQuantity: '100',
  mealUnit: 'gml',
  servingQuantity: null,
  servingUnit: 'gml',
  servingSize: '',
  nutriments: const MealNutrimentsEntity(
    energyKcal100: 100,
    carbohydrates100: 10,
    fat100: 5,
    proteins100: 5,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
  source: MealSourceEntity.custom,
);

RecipeEntity _recipe(String name) {
  final now = DateTime(2026, 1, 1);
  return RecipeEntity(
    id: name,
    name: name,
    description: null,
    ingredients: [
      RecipeIngredientEntity(
        snapshotMeal: _customMeal('$name ingredient'),
        amount: 150,
        unit: 'g',
        convertedAmountG: 150,
      ),
    ],
    totalWeightG: 150,
    aggregatedNutrimentsPer100: const MealNutrimentsEntity(
      energyKcal100: 100,
      carbohydrates100: 10,
      fat100: 5,
      proteins100: 5,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    createdAt: now,
    updatedAt: now,
    servingsCount: null,
  );
}

Widget _wrap({
  required List<MealEntity> customMeals,
  required List<RecipeEntity> recipes,
}) {
  GetIt.instance.registerFactory<CustomMealsBloc>(
    () => CustomMealsBloc(
      _FakeCustomMealDataSource(
        customMeals.map(MealDBO.fromMealEntity).toList(),
      ),
      _FakeGetIntakeUsecase(),
      _FakeDeleteIntakeUsecase(),
      _FakeAddTrackedDayUsecase(),
      _FakeMergeCustomMealsUseCase(),
    ),
  );
  final args = AddMealScreenArguments(
    AddMealType.breakfastType,
    DateTime(2026, 1, 1),
  );
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Builder(
      builder: (context) => Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(arguments: args),
          builder: (_) => PresetsScreen(
            getConfigUsecase: _FakeGetConfigUsecase(),
            recipeRepository: _FakeRecipeRepository()..recipes = recipes,
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => GetIt.instance.reset());

  group('PresetsScreen', () {
    testWidgets(
      'merges custom meals and saved recipes (Save as preset) into one list',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            customMeals: [_customMeal('Quick oats')],
            recipes: [_recipe('Chicken rice bowl')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Quick oats'), findsOneWidget);
        expect(find.textContaining('Chicken rice bowl'), findsOneWidget);
      },
    );

    testWidgets('shows the empty state when both sources are empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(customMeals: const [], recipes: const []));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
    });
  });
}
