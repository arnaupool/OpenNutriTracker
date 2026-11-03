import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorites_list.dart';
import 'package:opennutritracker/features/favorites/presentation/new_favorite_flow.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/meal_plan/presentation/meal_plan_page.dart';
import 'package:opennutritracker/features/scanner/data/product_not_found_exception.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import 'package:opennutritracker/features/scanner/presentation/scanner_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import 'in_memory_favorites.dart';

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 47,
  carbohydrates100: 4.8,
  fat100: 1.6,
  proteins100: 3.2,
  sugars100: null,
  saturatedFat100: null,
  fiber100: null,
);

MealEntity _offMeal(String code, String name) => MealEntity(
  code: code,
  name: name,
  url: null,
  mealQuantity: '1000',
  mealUnit: 'ml',
  servingQuantity: null,
  servingUnit: 'ml',
  servingSize: null,
  nutriments: _nutriments,
  source: MealSourceEntity.off,
);

FavoriteFoodEntity _leche({List<String> barcodes = const ['8410297112345']}) => FavoriteFoodEntity(
  id: 'f1',
  name: 'Leche',
  nutriments: _nutriments,
  unit: 'ml',
  portionName: 'vaso',
  portionQuantity: 250,
  barcodes: barcodes,
  originSource: 'off',
  originId: '8410297112345',
  createdAt: DateTime(2026, 11, 3),
  modifiedAt: DateTime(2026, 11, 3),
);

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

class _NoBarcodeLookup extends Fake implements SearchProductByBarcodeUseCase {
  int calls = 0;

  @override
  Future<MealEntity> searchProductByBarcode(String barcode) async {
    calls++;
    throw ProductNotFoundException();
  }
}

class _Recipes extends Fake implements RecipeRepository {
  @override
  List<RecipeEntity> getAllRecipes() => [];
}

class _CustomMeals extends Fake implements CustomMealDataSource {
  @override
  List<MealDBO> getAllCustomMeals() => [];
}

class _Intakes extends Fake implements IntakeRepository {
  @override
  Future<List<IntakeEntity>> getRecentIntake() async => [];
}

void main() {
  final getIt = GetIt.instance;
  late FavoriteFoodRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = inMemoryRepository();
    getIt.registerSingleton<FavoriteFoodRepository>(repo);
    getIt.registerSingleton<GetConfigUsecase>(_FakeConfig());
  });

  tearDown(() => getIt.reset());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('search ordering', () {
    test('matching favorites come first and replace the product they were copied from', () async {
      await repo.save(_leche());
      final bloc = ProductsBloc(
        _FakeSearch([_offMeal('1111111111111', 'Leche otra marca'), _offMeal('8410297112345', 'Leche entera')]),
        _FakeConfig(),
        repo,
      );
      addTearDown(bloc.close);

      bloc.add(const LoadProductsEvent(searchString: 'leche'));
      await settle();

      final state = bloc.state as ProductsLoadedState;
      expect(state.favorites.map((f) => f.name), ['Leche']);
      expect(state.products.map((m) => m.code), ['1111111111111'], reason: 'the copied product is not listed twice');
    });

    test('a query no favorite matches leaves the results alone; so does the food tab without favorites', () async {
      await repo.save(_leche());
      final bloc = ProductsBloc(_FakeSearch([_offMeal('1111111111111', 'Yogur')]), _FakeConfig(), repo);
      addTearDown(bloc.close);
      bloc.add(const LoadProductsEvent(searchString: 'yogur'));
      await settle();
      final state = bloc.state as ProductsLoadedState;
      expect(state.favorites, isEmpty);
      expect(state.products, hasLength(1));

      final food = FoodBloc(_FakeSearch([_offMeal('2222222222222', 'Leche FDC')]), _FakeConfig(), repo);
      addTearDown(food.close);
      food.add(const LoadFoodEvent(searchString: 'leche'));
      await settle();
      final foodState = food.state as FoodLoadedState;
      expect(foodState.favorites.map((f) => f.id), ['f1']);
      expect(foodState.food, hasLength(1));
    });

    testWidgets('a favorite card shows a star and opens the detail with the favorite', (tester) async {
      final fav = _leche();
      Object? args;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          home: Scaffold(
            body: MealItemCard(
              day: DateTime(2026, 11, 3),
              mealEntity: fav.toMealEntity(),
              addMealType: AddMealType.lunchType,
              usesImperialUnits: false,
              favorite: fav,
            ),
          ),
          routes: {
            NavigationOptions.mealDetailRoute: (context) {
              args = ModalRoute.of(context)!.settings.arguments;
              return const Scaffold(body: Text('detail'));
            },
          },
        ),
      );
      expect(find.byKey(const Key('favorite-star')), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect((args as MealDetailScreenArguments).favorite?.id, 'f1');
      expect((args as MealDetailScreenArguments).mealEntity.servingQuantity, 250);
    });
  });

  group('scanner precedence', () {
    test('a code carried by a favorite wins over every other source and never asks Open Food Facts', () async {
      await repo.save(_leche());
      final lookup = _NoBarcodeLookup();
      final bloc = ScannerBloc(lookup, _FakeConfig(), repo);
      addTearDown(bloc.close);

      bloc.add(const ScannerLoadProductEvent(barcode: '8410297112345'));
      await settle();

      final state = bloc.state as ScannerLoadedState;
      expect(state.favorite?.id, 'f1');
      expect(state.product.name, 'Leche');
      expect(state.product.servingQuantity, 250);
      expect(lookup.calls, 0);
    });

    test('an unknown code still goes to the normal lookup', () async {
      await repo.save(_leche());
      final lookup = _NoBarcodeLookup();
      final bloc = ScannerBloc(lookup, _FakeConfig(), repo);
      addTearDown(bloc.close);

      bloc.add(const ScannerLoadProductEvent(barcode: '5449000000996'));
      await settle();

      expect(bloc.state, const ScannerFailedState(ScannerFailedStateType.productNotFound));
      expect(lookup.calls, 1);
    });
  });

  group('Favoritos tab', () {
    Future<void> pump(WidgetTester tester, ValueNotifier<String> query, {Object? Function(Object?)? onDetail}) {
      return tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EnergyUnitProvider(),
          child: MaterialApp(
            localizationsDelegates: const [S.delegate],
            home: Scaffold(
              body: FavoritesList(query: query, day: DateTime(2026, 11, 3), mealType: AddMealType.lunchType),
            ),
            routes: {
              NavigationOptions.mealDetailRoute: (context) {
                onDetail?.call(ModalRoute.of(context)!.settings.arguments);
                return const Scaffold(body: Text('detail'));
              },
              NavigationOptions.favoriteEditorRoute: (context) => const Scaffold(body: Text('editor')),
            },
          ),
        ),
      );
    }

    testWidgets('lists favorites with their default portion, filters by the search text', (tester) async {
      await repo.save(_leche());
      await repo.save(_leche().copyWith(name: 'Pan integral', barcodes: []).copyWithId('f2'));
      final query = ValueNotifier('');
      await pump(tester, query);
      await tester.pumpAndSettle();
      expect(find.text('Leche'), findsOneWidget);
      expect(find.text('Pan integral'), findsOneWidget);
      expect(find.textContaining('vaso, 250 ml'), findsWidgets);

      query.value = 'lec';
      await tester.pumpAndSettle();
      expect(find.text('Leche'), findsOneWidget);
      expect(find.text('Pan integral'), findsNothing);

      query.value = 'zzz';
      await tester.pumpAndSettle();
      expect(find.text(S.current.favoritesNoMatch), findsOneWidget);
    });

    testWidgets('an empty list explains how to add favorites; tapping one opens the meal detail with its portion', (
      tester,
    ) async {
      final query = ValueNotifier('');
      MealDetailScreenArguments? opened;
      await pump(tester, query, onDetail: (a) => opened = a as MealDetailScreenArguments);
      await tester.pumpAndSettle();
      expect(find.text(S.current.favoritesEmpty), findsOneWidget);

      await repo.save(_leche());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leche'));
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
      expect(opened!.favorite?.id, 'f1');
      expect(opened!.mealEntity.hasServingValues, isTrue);
      expect(opened!.mealEntity.servingQuantity, 250);
    });

    testWidgets('the new-favorite button asks where the food comes from instead of opening a blank editor', (
      tester,
    ) async {
      await pump(tester, ValueNotifier(''));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.favoriteNew));
      await tester.pumpAndSettle();
      expect(find.text(S.current.favoriteSourceSearch), findsOneWidget);
      expect(find.text(S.current.favoriteSourceScan), findsOneWidget);
      expect(find.text(S.current.favoriteSourceAi), findsOneWidget);
      expect(find.text('editor'), findsNothing);
    });
  });

  group('meal plan picker', () {
    Future<void> pumpDialog(
      WidgetTester tester,
      Size size, {
      PlanDatabaseSearch? search,
      Map<String, WidgetBuilder> routes = const {},
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      getIt.registerSingleton<RecipeRepository>(_Recipes());
      getIt.registerSingleton<CustomMealDataSource>(_CustomMeals());
      getIt.registerSingleton<IntakeRepository>(_Intakes());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          routes: routes,
          home: Scaffold(
            body: AddPlanEntryDialog(databaseSearch: search, searchDelay: const Duration(milliseconds: 10)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    MealEntity offProduct(String code, String name) => MealEntity(
      code: code,
      name: name,
      brands: 'Hacendado',
      url: null,
      mealQuantity: '500',
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: _nutriments,
      source: MealSourceEntity.off,
    );

    testWidgets('typing adds a Base de datos column with the online results', (tester) async {
      await repo.save(_leche());
      final queries = <String>[];
      await pumpDialog(
        tester,
        const Size(1400, 900),
        search: (q) async {
          queries.add(q);
          return [offProduct('111', 'Leche de avena')];
        },
      );
      expect(find.text(S.current.planDatabaseColumn), findsNothing);

      await tester.enterText(find.byType(TextField), 'leche');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text(S.current.planDatabaseColumn), findsOneWidget);
      expect(find.text('Leche de avena'), findsOneWidget);
      expect(queries, ['leche']);

      await tester.tap(find.text('Leche de avena'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '100'), findsOneWidget);
    });

    testWidgets('the phone gets a Base de datos tab only while there is text', (tester) async {
      await pumpDialog(tester, const Size(500, 900), search: (q) async => [offProduct('111', 'Leche de avena')]);
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
      await tester.enterText(find.byType(TextField), 'leche');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs.map((t) => (t as Tab).text).toList();
      expect(tabs.last, S.current.planDatabaseColumn);
    });

    testWidgets('short text does not ask the databases', (tester) async {
      var calls = 0;
      await pumpDialog(
        tester,
        const Size(1400, 900),
        search: (q) async {
          calls++;
          return [];
        },
      );
      await tester.enterText(find.byType(TextField), 'le');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('New favorite copies the chosen food, opens the editor and comes back with it ready to add', (
      tester,
    ) async {
      Future<List<MealEntity>?> none(BuildContext context) async => null;
      debugNewFavoritePickers = NewFavoritePickers(
        search: (context) async => [
          MealEntity(
            code: '8410297112345',
            name: 'Leche',
            url: null,
            mealQuantity: '1000',
            mealUnit: 'ml',
            servingQuantity: 250,
            servingUnit: 'ml',
            servingSize: 'vaso',
            nutriments: _nutriments,
            source: MealSourceEntity.off,
            detailed: true,
          ),
        ],
        scan: none,
        ai: none,
      );
      addTearDown(() => debugNewFavoritePickers = null);
      await pumpDialog(
        tester,
        const Size(1400, 900),
        routes: {
          NavigationOptions.favoriteEditorRoute: (context) => Scaffold(
            body: TextButton(onPressed: () => Navigator.of(context).pop('done'), child: const Text('close editor')),
          ),
        },
      );
      expect(find.text('Leche'), findsNothing);
      await tester.tap(find.text(S.current.favoriteNew));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.favoriteSourceSearch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('close editor'));
      await tester.pumpAndSettle();
      // Back in the dialog, the new favorite is selected with its portion.
      expect(find.text('Leche'), findsOneWidget);
      expect(find.widgetWithText(TextField, '250'), findsOneWidget);
    });

    testWidgets('New recipe opens the recipe builder', (tester) async {
      await pumpDialog(
        tester,
        const Size(1400, 900),
        routes: {NavigationOptions.recipeBuilderRoute: (context) => const Scaffold(body: Text('builder'))},
      );
      await tester.tap(find.text(S.current.planNewRecipe));
      await tester.pumpAndSettle();
      expect(find.text('builder'), findsOneWidget);
    });

    testWidgets('desktop shows a Favoritos column next to recipes and recent', (tester) async {
      await repo.save(_leche());
      await pumpDialog(tester, const Size(1400, 900));
      expect(find.byType(TabBar), findsNothing);
      expect(find.text(S.current.favoritesTitle), findsOneWidget);
      expect(find.text(S.current.recipesLabel), findsOneWidget);
      expect(find.text(S.current.addItemMenuRecentlyLabel), findsOneWidget);
      expect(find.text('Leche'), findsOneWidget);
    });

    testWidgets('the phone has a Favoritos tab, first, with the favorite in it', (tester) async {
      await repo.save(_leche());
      await pumpDialog(tester, const Size(500, 900));
      final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs.map((t) => (t as Tab).text).toList();
      expect(tabs, [S.current.favoritesTitle, S.current.recipesLabel, S.current.addItemMenuRecentlyLabel]);
      expect(find.text('Leche'), findsOneWidget);
    });

    testWidgets('picking a favorite plans its default portion', (tester) async {
      await repo.save(_leche());
      await pumpDialog(tester, const Size(1400, 900));
      await tester.tap(find.text('Leche'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '250'), findsOneWidget);
    });

    test('a plan entry holds its own meal, so deleting the favorite leaves it intact', () async {
      final fav = _leche();
      await repo.save(fav);
      final entry = MealPlanEntryDBO(
        id: 'p1',
        day: DateTime(2026, 11, 4),
        type: IntakeTypeDBO.breakfast,
        meal: MealDBO.fromMealEntity(fav.toMealEntity()),
        amount: 250,
        unit: 'ml',
      );
      await repo.delete('f1');
      expect(repo.getById('f1'), isNull);
      expect(entry.meal.name, 'Leche');
      expect(entry.meal.nutriments.energyKcal100, 47);
      expect(
        MealPlanEntryDBO.fromJson(jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>).meal.name,
        'Leche',
      );
    });
  });
}

extension on FavoriteFoodEntity {
  /// Same favorite under another id, for list tests.
  FavoriteFoodEntity copyWithId(String newId) => FavoriteFoodEntity(
    id: newId,
    name: name,
    nutriments: nutriments,
    unit: unit,
    portionName: portionName,
    portionQuantity: portionQuantity,
    barcodes: barcodes,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );
}
