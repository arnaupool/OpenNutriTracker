import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The user's favorite foods inside the Recipes page (a column on desktop, a
/// tab on the phone). Tapping one opens the favorite editor.
class FavoritesTab extends StatelessWidget {
  final FavoriteFoodRepository? repository;

  const FavoritesTab({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? locator<FavoriteFoodRepository>();
    return ListenableBuilder(
      listenable: repo.listenable(),
      builder: (context, _) {
        final favorites = repo.getAll();
        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(S.of(context).favoritesEmpty, textAlign: TextAlign.center),
            ),
          );
        }
        return Semantics(
          identifier: 'recipes-favorites-list',
          child: ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) => _FavoriteRow(favorite: favorites[index]),
          ),
        );
      },
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final FavoriteFoodEntity favorite;

  const _FavoriteRow({required this.favorite});

  @override
  Widget build(BuildContext context) {
    final kcal = favorite.nutriments.energyKcal100;
    final per100 = kcal == null ? null : '${EnergyDisplay.formatWithUnit(context, kcal)} / 100 ${favorite.unit}';
    final subtitle = [per100, favorite.portionLabel].whereType<String>().join(' · ');
    final brand = favorite.brand;
    return ListTile(
      leading: const Icon(Icons.star, color: Colors.amber),
      title: Text(brand == null || brand.isEmpty ? favorite.name : '${favorite.name} ($brand)'),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(NavigationOptions.favoriteEditorRoute, arguments: FavoriteEditorArguments(favoriteId: favorite.id)),
    );
  }
}
