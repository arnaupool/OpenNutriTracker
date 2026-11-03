import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/features/favorites/presentation/new_favorite_flow.dart';
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
);

MealEntity _meal({
  required String code,
  required String name,
  required MealSourceEntity source,
  double? serving,
  String? brands,
}) => MealEntity(
  code: code,
  name: name,
  brands: brands,
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: serving,
  servingUnit: serving == null ? null : 'g',
  servingSize: null,
  nutriments: _nutriments,
  source: source,
  detailed: true,
);

void main() {
  final getIt = GetIt.instance;
  late FavoriteFoodRepository repo;
  String? returnedId;
  Object? editorArgs;

  setUp(() async {
    await getIt.reset();
    repo = inMemoryRepository();
    getIt.registerSingleton<FavoriteFoodRepository>(repo);
    returnedId = null;
    editorArgs = null;
  });

  tearDown(() async {
    debugNewFavoritePickers = null;
    await getIt.reset();
  });

  Future<void> openChooser(WidgetTester tester) async {
    await tester.tap(find.text('new favorite'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpHost(WidgetTester tester, NewFavoritePickers pickers) async {
    debugNewFavoritePickers = pickers;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        routes: {
          NavigationOptions.favoriteEditorRoute: (context) {
            editorArgs = ModalRoute.of(context)!.settings.arguments;
            return Scaffold(appBar: AppBar(), body: const Text('editor'));
          },
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => returnedId = await startNewFavorite(context),
              child: const Text('new favorite'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openChooser(tester);
  }

  Future<List<MealEntity>?> nothing(BuildContext context) async => null;

  testWidgets('the chooser offers database, barcode and AI', (tester) async {
    await pumpHost(tester, NewFavoritePickers(search: nothing, scan: nothing, ai: nothing));
    expect(find.text(S.current.favoriteSourceSearch), findsOneWidget);
    expect(find.text(S.current.favoriteSourceScan), findsOneWidget);
    expect(find.text(S.current.favoriteSourceAi), findsOneWidget);
  });

  testWidgets('database: the chosen food is copied as a favorite and the editor opens on it', (tester) async {
    await pumpHost(
      tester,
      NewFavoritePickers(
        search: (context) async => [_meal(code: 'fdc-1', name: 'Manzana', source: MealSourceEntity.fdc, serving: 182)],
        scan: nothing,
        ai: nothing,
      ),
    );
    await tester.tap(find.text(S.current.favoriteSourceSearch));
    await tester.pumpAndSettle();

    final all = repo.getAll();
    expect(all, hasLength(1));
    final fav = all.single;
    expect(fav.name, 'Manzana');
    expect(fav.nutriments.energyKcal100, 47);
    expect(fav.portionQuantity, 182);
    expect(fav.originSource, 'fdc');
    expect(find.text('editor'), findsOneWidget);
    expect((editorArgs as FavoriteEditorArguments).favoriteId, fav.id);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returnedId, fav.id);
  });

  testWidgets('scan: the scanned barcode goes into the favorite barcode list', (tester) async {
    await pumpHost(
      tester,
      NewFavoritePickers(
        search: nothing,
        scan: (context) async => [
          _meal(code: '8410297112345', name: 'Leche entera', source: MealSourceEntity.off, brands: 'Hacendado'),
        ],
        ai: nothing,
      ),
    );
    await tester.tap(find.text(S.current.favoriteSourceScan));
    await tester.pumpAndSettle();

    final fav = repo.getAll().single;
    expect(fav.name, 'Leche entera');
    expect(fav.brand, 'Hacendado');
    expect(fav.barcodes, ['8410297112345']);
    expect(find.text('editor'), findsOneWidget);
    expect((editorArgs as FavoriteEditorArguments).favoriteId, fav.id);
  });

  testWidgets('a food that already is a favorite opens that one instead of copying it twice', (tester) async {
    await pumpHost(
      tester,
      NewFavoritePickers(
        search: nothing,
        scan: (context) async => [_meal(code: '8410297112345', name: 'Leche', source: MealSourceEntity.off)],
        ai: nothing,
      ),
    );
    await tester.tap(find.text(S.current.favoriteSourceScan));
    await tester.pumpAndSettle();
    final existingId = repo.getAll().single.id;

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returnedId, existingId);
    returnedId = null;
    await openChooser(tester);
    await tester.tap(find.text(S.current.favoriteSourceScan));
    await tester.pumpAndSettle();
    expect((editorArgs as FavoriteEditorArguments).favoriteId, existingId);
    expect(repo.getAll(), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returnedId, existingId);
  });

  testWidgets('AI: each chosen food becomes a favorite and the editor opens on the first', (tester) async {
    await pumpHost(
      tester,
      NewFavoritePickers(
        search: nothing,
        scan: nothing,
        ai: (context) async => [
          _meal(code: 'ai-1', name: 'Arroz', source: MealSourceEntity.custom, serving: 150),
          _meal(code: 'ai-2', name: 'Pollo', source: MealSourceEntity.custom, serving: 120),
        ],
      ),
    );
    await tester.tap(find.text(S.current.favoriteSourceAi));
    await tester.pumpAndSettle();

    final all = repo.getAll();
    expect(all.map((f) => f.name).toSet(), {'Arroz', 'Pollo'});
    expect(all.firstWhere((f) => f.name == 'Arroz').portionQuantity, 150);
    expect(find.text('editor'), findsOneWidget);
    final openedId = (editorArgs as FavoriteEditorArguments).favoriteId;
    expect(all.map((f) => f.id), contains(openedId));
    expect(repo.getById(openedId!)!.name, 'Arroz');
  });

  testWidgets('dismissing the chooser creates nothing', (tester) async {
    await pumpHost(tester, NewFavoritePickers(search: nothing, scan: nothing, ai: nothing));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(repo.getAll(), isEmpty);
    expect(find.text('editor'), findsNothing);
    expect(returnedId, isNull);
  });

  for (final entry in {
    NewFavoriteSource.search: () => S.current.favoriteSourceSearch,
    NewFavoriteSource.scan: () => S.current.favoriteSourceScan,
    NewFavoriteSource.ai: () => S.current.favoriteSourceAi,
  }.entries) {
    testWidgets('cancelling the ${entry.key.name} step creates nothing and opens no editor', (tester) async {
      await pumpHost(tester, NewFavoritePickers(search: nothing, scan: nothing, ai: nothing));
      await tester.tap(find.text(entry.value()));
      await tester.pumpAndSettle();
      expect(repo.getAll(), isEmpty);
      expect(find.text('editor'), findsNothing);
      expect(returnedId, isNull);
    });
  }
}
