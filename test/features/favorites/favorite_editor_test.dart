import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_star_button.dart';
import 'package:opennutritracker/features/scanner/presentation/barcode_capture_page.dart';
import 'package:opennutritracker/features/scanner/util/camera_scanner_support.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/generated/l10n.dart';

import 'in_memory_favorites.dart';

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 47,
  carbohydrates100: 4.8,
  fat100: 1.6,
  proteins100: 3.2,
  sugars100: 4.8,
  saturatedFat100: 1,
  fiber100: 0,
  calcium100: 120,
);

MealEntity _offMilk({double? servingQuantity = 250, String? servingSize = 'vaso', String unit = 'ml'}) => MealEntity(
  code: '8410297112345',
  name: 'Leche entera',
  brands: 'Hacendado',
  url: null,
  mealQuantity: '1000',
  mealUnit: unit,
  servingQuantity: servingQuantity,
  servingUnit: unit,
  servingSize: servingSize,
  nutriments: _nutriments,
  source: MealSourceEntity.off,
  detailed: true,
);

FavoriteFoodEntity _fav({String id = 'f1', String name = 'Leche', List<String> barcodes = const []}) =>
    FavoriteFoodEntity(
      id: id,
      name: name,
      nutriments: _nutriments,
      unit: 'ml',
      barcodes: barcodes,
      createdAt: DateTime(2026, 11, 3),
      modifiedAt: DateTime(2026, 11, 3),
    );

void main() {
  final getIt = GetIt.instance;
  late FavoriteFoodRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = inMemoryRepository();
    getIt.registerSingleton<FavoriteFoodRepository>(repo);
  });

  tearDown(() => getIt.reset());

  group('FavoriteFoodEntity.fromMeal', () {
    final now = DateTime(2026, 11, 3);

    test('copies macros per 100, unit, barcode, origin and a default portion from the serving', () {
      final fav = FavoriteFoodEntity.fromMeal(
        _offMilk(servingSize: 'vaso'),
        id: 'a',
        now: now,
      );
      expect(fav.name, 'Leche entera');
      expect(fav.brand, 'Hacendado');
      expect(fav.unit, 'ml');
      expect(fav.nutriments.energyKcal100, 47);
      expect(fav.nutriments.calcium100, 120);
      expect(fav.portionQuantity, 250);
      expect(fav.portionName, 'vaso');
      expect(fav.barcodes, ['8410297112345']);
      expect(fav.originSource, 'off');
      expect(fav.originId, '8410297112345');
    });

    test('a serving size that is only a quantity gives no portion name', () {
      final fav = FavoriteFoodEntity.fromMeal(
        _offMilk(servingSize: '250 ml'),
        id: 'a',
        now: now,
      );
      expect(fav.portionQuantity, 250);
      expect(fav.portionName, isNull);
    });

    test('no serving means no default portion; solids stay in grams', () {
      final fav = FavoriteFoodEntity.fromMeal(
        _offMilk(servingQuantity: null, servingSize: null, unit: 'g'),
        id: 'a',
        now: now,
      );
      expect(fav.portionQuantity, isNull);
      expect(fav.unit, 'g');
    });

    test('an FDC id is not taken for a barcode, a scanned code is', () {
      const fdc = MealEntity(
        code: '1102653',
        name: 'Milk',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        nutriments: _nutriments,
        source: MealSourceEntity.fdc,
      );
      expect(FavoriteFoodEntity.fromMeal(fdc, id: 'a', now: now).barcodes, isEmpty);
      expect(FavoriteFoodEntity.fromMeal(fdc, id: 'a', now: now, barcode: '5449000000996').barcodes, ['5449000000996']);
    });

    test('toMealEntity starts from the default portion and keeps the favorite code', () {
      final fav = FavoriteFoodEntity.fromMeal(_offMilk(), id: 'a', now: now);
      final meal = fav.toMealEntity();
      expect(meal.code, '8410297112345');
      expect(meal.servingQuantity, 250);
      expect(meal.hasServingValues, isTrue);
      expect(meal.mealUnit, 'ml');
      expect(_fav().toMealEntity().code, 'fav:f1');
      expect(_fav().toMealEntity().hasServingValues, isFalse);
    });
  });

  Widget app(Widget home, {Map<String, WidgetBuilder> routes = const {}}) => MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: home,
    routes: routes,
  );

  group('FavoriteStarButton', () {
    testWidgets('an empty star saves the copy and opens the editor; a filled star only opens it', (tester) async {
      Object? opened;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(child: FavoriteStarButton(meal: _offMilk())),
          ),
          routes: {
            NavigationOptions.favoriteEditorRoute: (context) {
              opened = ModalRoute.of(context)!.settings.arguments;
              return Scaffold(appBar: AppBar(), body: const Text('editor'));
            },
          },
        ),
      );
      expect(find.byIcon(Icons.star_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();
      expect(find.text('editor'), findsOneWidget);
      final saved = repo.getAll().single;
      expect((opened as FavoriteEditorArguments).favoriteId, saved.id);
      expect(saved.barcodes, ['8410297112345']);
      expect(saved.portionQuantity, 250);

      // Back: the star is now filled and a second tap does not duplicate.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      expect(repo.getAll(), hasLength(1));
    });
  });

  group('FavoriteEditorScreen', () {
    Future<void> open(WidgetTester tester, FavoriteEditorArguments args) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed(NavigationOptions.favoriteEditorRoute, arguments: args),
              child: const Text('open'),
            ),
          ),
          routes: {NavigationOptions.favoriteEditorRoute: (_) => const FavoriteEditorScreen()},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder field(String id) => find.descendant(
      of: find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id),
      matching: find.byType(EditableText),
    );

    Future<void> type(WidgetTester tester, String id, String text) async {
      await tester.enterText(field(id), text);
      await tester.pump();
    }

    Future<void> tapId(WidgetTester tester, String id) async {
      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id));
      await tester.pumpAndSettle();
    }

    testWidgets('a new favorite needs a name and an energy value, and nothing is saved until they are valid', (
      tester,
    ) async {
      await open(tester, const FavoriteEditorArguments());
      await tapId(tester, 'favorite-save');
      expect(repo.getAll(), isEmpty);
      expect(find.text(S.current.mealNameValidationError), findsOneWidget);
      expect(find.text(S.current.favoriteNumberInvalid), findsOneWidget);

      await type(tester, 'favorite-name', 'Leche');
      await type(tester, 'favorite-kcal', '-3');
      await tapId(tester, 'favorite-save');
      expect(repo.getAll(), isEmpty);
      expect(find.text(S.current.favoriteNumberInvalid), findsOneWidget);
    });

    testWidgets('a portion name without a size is refused; a full form is saved with portion and codes', (
      tester,
    ) async {
      await open(tester, const FavoriteEditorArguments());
      await type(tester, 'favorite-name', 'Leche');
      await type(tester, 'favorite-kcal', '47,5');
      await type(tester, 'favorite-portion-name', 'vaso');
      await tapId(tester, 'favorite-save');
      expect(repo.getAll(), isEmpty);
      expect(find.text(S.current.favoritePortionInvalid), findsOneWidget);

      await type(tester, 'favorite-portion-quantity', '250');
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<String>), matching: find.text('ml')));
      await tester.pump();
      await type(tester, 'favorite-barcode-input', '8410297112345');
      await tapId(tester, 'favorite-barcode-add');
      expect(find.text('8410297112345'), findsOneWidget);
      await tapId(tester, 'favorite-save');

      final saved = repo.getAll().single;
      expect(saved.name, 'Leche');
      expect(saved.unit, 'ml');
      expect(saved.nutriments.energyKcal100, 47.5);
      expect(saved.portionName, 'vaso');
      expect(saved.portionQuantity, 250);
      expect(saved.barcodes, ['8410297112345']);
      expect(saved.originSource, isNull);
    });

    testWidgets('barcodes: invalid, repeated and taken codes are refused; a chip can be removed', (tester) async {
      await repo.save(_fav(id: 'other', name: 'Otro', barcodes: ['5449000000996']));
      await repo.save(_fav(barcodes: ['8410297112345']));
      await open(tester, const FavoriteEditorArguments(favoriteId: 'f1'));
      expect(find.text('8410297112345'), findsOneWidget);

      await type(tester, 'favorite-barcode-input', '123');
      await tapId(tester, 'favorite-barcode-add');
      expect(find.text(S.current.customMealBarcodeInvalid), findsOneWidget);

      await type(tester, 'favorite-barcode-input', '8410297112345');
      await tapId(tester, 'favorite-barcode-add');
      expect(find.text(S.current.favoriteBarcodeDuplicate), findsOneWidget);

      await type(tester, 'favorite-barcode-input', '5449000000996');
      await tapId(tester, 'favorite-barcode-add');
      expect(find.text(S.current.favoriteBarcodeTaken), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.text('8410297112345'), findsNothing);
      await tapId(tester, 'favorite-save');
      expect(repo.getById('f1')!.barcodes, isEmpty);
    });

    testWidgets('on web the scan button opens the camera scanner, with typing as the secondary option', (tester) async {
      cameraScannerSupportOverride = true;
      addTearDown(() => cameraScannerSupportOverride = null);
      await open(tester, const FavoriteEditorArguments());

      await tapId(tester, 'favorite-barcode-scan');

      expect(find.byType(BarcodeCapturePage), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'barcode-capture-field'),
        findsOneWidget,
      );
    });

    testWidgets('without camera support the scanner page offers only typing', (tester) async {
      cameraScannerSupportOverride = false;
      addTearDown(() => cameraScannerSupportOverride = null);
      await open(tester, const FavoriteEditorArguments());

      await tapId(tester, 'favorite-barcode-scan');

      expect(find.byType(BarcodeCapturePage), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
    });

    testWidgets('editing changes the favorite, never its id or origin', (tester) async {
      final original = FavoriteFoodEntity.fromMeal(_offMilk(), id: 'f1', now: DateTime(2026, 11, 3));
      await repo.save(original);
      await open(tester, const FavoriteEditorArguments(favoriteId: 'f1'));
      await type(tester, 'favorite-kcal', '60');
      await type(tester, 'favorite-portion-quantity', '200');
      await tapId(tester, 'favorite-save');
      final edited = repo.getById('f1')!;
      expect(edited.nutriments.energyKcal100, 60);
      expect(edited.nutriments.calcium100, 120, reason: 'micronutrients are kept');
      expect(edited.portionQuantity, 200);
      expect(edited.originId, '8410297112345');
      expect(edited.createdAt, original.createdAt);
    });

    testWidgets('delete asks for confirmation and removes the favorite', (tester) async {
      await repo.save(_fav());
      await open(tester, const FavoriteEditorArguments(favoriteId: 'f1'));
      await tapId(tester, 'favorite-delete');
      await tester.tap(find.text(S.current.dialogCancelLabel));
      await tester.pumpAndSettle();
      expect(repo.getAll(), hasLength(1));

      await tapId(tester, 'favorite-delete');
      await tapId(tester, 'favorite-delete-confirm');
      expect(repo.getAll(), isEmpty);
      expect(find.text('open'), findsOneWidget, reason: 'back on the previous screen');
    });
  });
}
