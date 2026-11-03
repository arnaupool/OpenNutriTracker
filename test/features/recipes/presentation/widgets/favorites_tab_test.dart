import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/favorites_tab.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../../../favorites/in_memory_favorites.dart';

FavoriteFoodEntity _fav(String id, String name) => FavoriteFoodEntity(
  id: id,
  name: name,
  nutriments: const MealNutrimentsEntity(
    energyKcal100: 47,
    carbohydrates100: 4.8,
    fat100: 1.6,
    proteins100: 3.2,
    sugars100: 4.8,
    saturatedFat100: 1,
    fiber100: 0,
  ),
  unit: 'ml',
  barcodes: const [],
  createdAt: DateTime(2026, 11, 3),
  modifiedAt: DateTime(2026, 11, 3),
);

Widget _host(FavoritesTab tab) => ChangeNotifierProvider<EnergyUnitProvider>(
  create: (_) => EnergyUnitProvider(),
  child: MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: tab),
  ),
);

void main() {
  testWidgets('shows the empty hint without favorites', (tester) async {
    final repo = inMemoryRepository();
    await tester.pumpWidget(_host(FavoritesTab(repository: repo)));
    expect(find.textContaining('Favorites'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('lists favorites and follows later changes', (tester) async {
    final source = InMemoryFavoriteDataSource();
    final repo = inMemoryRepository(source);
    await repo.save(_fav('a', 'Leche'));
    await tester.pumpWidget(_host(FavoritesTab(repository: repo)));
    expect(find.text('Leche'), findsOneWidget);

    await repo.save(_fav('b', 'Yogur'));
    await tester.pump();
    expect(find.text('Yogur'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
