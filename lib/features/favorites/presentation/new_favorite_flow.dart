import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Where the food of a new favorite comes from. A favorite is always a copy
/// of a food found elsewhere; foods made from scratch are custom meals.
enum NewFavoriteSource { search, scan, ai }

/// Runs one way of finding foods and returns them, or null when the user
/// backed out. Replaced in tests.
typedef FoodPicker = Future<List<MealEntity>?> Function(BuildContext context);

class NewFavoritePickers {
  final FoodPicker search;
  final FoodPicker scan;
  final FoodPicker ai;

  const NewFavoritePickers({required this.search, required this.scan, required this.ai});

  /// The real flows, each in its "pick" mode.
  factory NewFavoritePickers.standard() =>
      NewFavoritePickers(search: _pickFromSearch, scan: _pickFromScan, ai: _pickFromAi);

  FoodPicker of(NewFavoriteSource source) => switch (source) {
    NewFavoriteSource.search => search,
    NewFavoriteSource.scan => scan,
    NewFavoriteSource.ai => ai,
  };
}

Future<List<MealEntity>?> _pickFromSearch(BuildContext context) async {
  final picked = await Navigator.of(context).pushNamed(
    NavigationOptions.addMealRoute,
    arguments: AddMealScreenArguments(AddMealType.snackType, DateTime.now(), pickMode: true),
  );
  if (picked is! MealEntity) return null;
  return [await _withFullRecord(picked)];
}

Future<List<MealEntity>?> _pickFromScan(BuildContext context) async {
  final picked = await Navigator.of(
    context,
  ).pushNamed(NavigationOptions.scannerRoute, arguments: ScannerScreenArguments.pick());
  return picked is MealEntity ? [picked] : null;
}

Future<List<MealEntity>?> _pickFromAi(BuildContext context) async {
  final picked = await Navigator.of(context).pushNamed(
    NavigationOptions.magicRoute,
    arguments: AddMealScreenArguments(AddMealType.snackType, DateTime.now(), pickMode: true),
  );
  return picked is List<MealEntity> && picked.isNotEmpty ? picked : null;
}

/// Open Food Facts text search returns a thin record; the full one carries
/// the serving size and micronutrients. Keeps the thin one when offline.
Future<MealEntity> _withFullRecord(MealEntity meal) async {
  final code = meal.code;
  if (meal.source != MealSourceEntity.off || meal.detailed || code == null || code.isEmpty) return meal;
  try {
    return await locator<ProductsRepository>().getOFFProductByBarcode(code);
  } catch (_) {
    return meal;
  }
}

/// Replaces the real flows for every caller (widget tests).
@visibleForTesting
NewFavoritePickers? debugNewFavoritePickers;

/// Asks where the food comes from, runs that flow, copies the chosen food(s)
/// as favorites (what the star button does) and opens the editor of the
/// first one so the user can adjust it. Returns the id of that favorite, or
/// null when the user cancelled at any step (nothing is created then).
///
/// A food that already is a favorite (same barcode or origin) is not copied
/// twice: its existing favorite is opened instead.
Future<String?> startNewFavorite(BuildContext context, {NewFavoritePickers? pickers}) async {
  final source = await showDialog<NewFavoriteSource>(context: context, builder: (_) => const NewFavoriteChooser());
  if (source == null || !context.mounted) return null;
  final meals = await (pickers ?? debugNewFavoritePickers ?? NewFavoritePickers.standard()).of(source)(context);
  if (meals == null || meals.isEmpty || !context.mounted) return null;

  final repo = locator<FavoriteFoodRepository>();
  final ids = <String>[];
  for (final meal in meals) {
    var favorite = repo.findForMeal(meal.code, meal.source.name);
    if (favorite == null) {
      favorite = FavoriteFoodEntity.fromMeal(meal, id: IdGenerator.getUniqueID(), now: DateTime.now());
      await repo.save(favorite);
    }
    ids.add(favorite.id);
  }
  if (!context.mounted) return ids.first;
  if (ids.length > 1) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).favoritesCreated)));
  }
  await Navigator.of(
    context,
  ).pushNamed(NavigationOptions.favoriteEditorRoute, arguments: FavoriteEditorArguments(favoriteId: ids.first));
  return ids.first;
}

/// The small "where does the food come from" chooser.
class NewFavoriteChooser extends StatelessWidget {
  const NewFavoriteChooser({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget option(String id, IconData icon, String label, NewFavoriteSource source) => Semantics(
      identifier: id,
      child: SimpleDialogOption(
        onPressed: () => Navigator.of(context).pop(source),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
    return SimpleDialog(
      title: Text(s.favoriteSourceTitle),
      children: [
        option('new-favorite-search', Icons.search, s.favoriteSourceSearch, NewFavoriteSource.search),
        option('new-favorite-scan', Icons.qr_code_scanner_outlined, s.favoriteSourceScan, NewFavoriteSource.scan),
        option('new-favorite-ai', Icons.auto_awesome_outlined, s.favoriteSourceAi, NewFavoriteSource.ai),
      ],
    );
  }
}
