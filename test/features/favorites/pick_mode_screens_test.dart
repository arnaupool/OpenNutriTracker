import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:provider/provider.dart';

import 'in_memory_favorites.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/review_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeSearch extends Fake implements SearchProductsUseCase {
  final List<MealEntity> meals;
  _FakeSearch(this.meals);

  @override
  Future<SearchProductsResult> searchOFFProductsByString(String searchString, {bool skipRemote = false}) async =>
      SearchProductsResult(meals: meals, remoteSourceEmpty: false);

  @override
  Future<SearchProductsResult> searchFDCFoodByString(String searchString, {bool skipRemote = false}) async =>
      SearchProductsResult(meals: meals, remoteSourceEmpty: false);
}

class _FakeConfig extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async => const ConfigEntity(false, false, false, AppThemeEntity.dark);
}

void main() {
  final getIt = GetIt.instance;

  testWidgets('the search screen in pick mode has no favorites tab and returns the tapped product', (tester) async {
    await getIt.reset();
    final repo = inMemoryRepository();
    getIt.registerSingleton<FavoriteFoodRepository>(repo);
    final milk = MealEntity(
      code: '8410297112345',
      name: 'Leche',
      url: null,
      mealQuantity: '1000',
      mealUnit: 'ml',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsEntity.empty(),
      source: MealSourceEntity.off,
    );
    getIt.registerFactory<ProductsBloc>(() => ProductsBloc(_FakeSearch([milk]), _FakeConfig(), repo));
    getIt.registerFactory<FoodBloc>(() => FoodBloc(_FakeSearch([milk]), _FakeConfig(), repo));
    addTearDown(getIt.reset);

    MealEntity? result;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<MealEntity>(
                  MaterialPageRoute(
                    settings: RouteSettings(
                      arguments: AddMealScreenArguments(AddMealType.snackType, DateTime(2026, 11, 3), pickMode: true),
                    ),
                    builder: (_) => const AddMealScreen(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(S.current.favoritesTitle), findsNothing);
    expect(find.text(S.current.searchProductsPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'leche');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(result, milk);
  });

  const items = [
    MagicFoodItemEntity(name: 'Arroz', kcal: 200, grams: 150, carbsG: 45, fatG: 1, proteinG: 4),
    MagicFoodItemEntity(name: 'Pollo', kcal: 180, grams: 120, carbsG: 0, fatG: 6, proteinG: 30),
  ];

  testWidgets('the AI review in pick mode returns only the ticked foods, with the AI portion as serving', (
    tester,
  ) async {
    List<MealEntity>? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await Navigator.of(context).push<List<MealEntity>>(
                MaterialPageRoute(
                  settings: RouteSettings(
                    arguments: ReviewMealScreenArguments(
                      items: items,
                      imageBytes: null,
                      mealType: AddMealType.lunchType,
                      day: DateTime(2026, 11, 3),
                      pickMode: true,
                    ),
                  ),
                  builder: (_) => const ReviewMealScreen(),
                ),
              );
              result = r;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No meal type selector, no log-all or preset buttons.
    expect(find.text(S.current.favoriteCreateSelected), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text(S.current.favoriteCreateSelected));
    await tester.pumpAndSettle();

    expect(result, hasLength(1));
    expect(result!.single.name, 'Arroz');
    expect(result!.single.servingQuantity, 150);
    expect(result!.single.nutriments.energyKcal100, closeTo(200 * 100 / 150, 0.001));
  });

  testWidgets('a food card in pick mode hands the food back instead of opening its detail', (tester) async {
    final meal = MealEntity(
      code: '8410297112345',
      name: 'Leche',
      url: null,
      mealQuantity: '1000',
      mealUnit: 'ml',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsEntity.empty(),
      source: MealSourceEntity.off,
    );
    MealEntity? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: Scaffold(
          body: MealItemCard(
            day: DateTime(2026, 11, 3),
            mealEntity: meal,
            addMealType: AddMealType.snackType,
            usesImperialUnits: false,
            onPick: (m) => picked = m,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ListTile));
    expect(picked, meal);
  });
}
