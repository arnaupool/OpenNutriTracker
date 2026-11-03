import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/utils/off_image_url.dart';

/// The "Favoritos" tab of the add-meal screen: a "New favorite" button and the
/// favorites (filtered by the search text). Tapping one opens the regular meal
/// detail with its default portion filled in, editable before saving.
class FavoritesList extends StatefulWidget {
  final ValueListenable<String> query;
  final DateTime day;
  final AddMealType mealType;

  const FavoritesList({super.key, required this.query, required this.day, required this.mealType});

  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList> {
  final FavoriteFoodRepository _repo = locator<FavoriteFoodRepository>();
  bool _usesImperialUnits = false;

  @override
  void initState() {
    super.initState();
    locator<GetConfigUsecase>().getConfig().then((config) {
      if (mounted) setState(() => _usesImperialUnits = config.usesImperialUnits);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Semantics(
              identifier: 'favorites-new',
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.star_border),
                label: Text(s.favoriteNew),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(NavigationOptions.favoriteEditorRoute, arguments: const FavoriteEditorArguments()),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([_repo.listenable(), widget.query]),
            builder: (context, _) {
              final query = widget.query.value.trim();
              final all = _repo.getAll();
              final shown = query.isEmpty ? all : _repo.search(query);
              if (shown.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(all.isEmpty ? s.favoritesEmpty : s.favoritesNoMatch, textAlign: TextAlign.center),
                );
              }
              return Semantics(
                identifier: 'favorites-list',
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) => _FavoriteTile(
                    favorite: shown[index],
                    onTap: () => _log(shown[index]),
                    onEdit: () => Navigator.of(context).pushNamed(
                      NavigationOptions.favoriteEditorRoute,
                      arguments: FavoriteEditorArguments(favoriteId: shown[index].id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _log(FavoriteFoodEntity favorite) {
    Navigator.of(context).pushNamed(
      NavigationOptions.mealDetailRoute,
      arguments: MealDetailScreenArguments(
        favorite.toMealEntity(),
        widget.mealType.getIntakeType(),
        widget.day,
        _usesImperialUnits,
        favorite: favorite,
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final FavoriteFoodEntity favorite;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _FavoriteTile({required this.favorite, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final kcal = favorite.nutriments.energyKcal100;
    final per100 = kcal == null ? null : '${EnergyDisplay.formatWithUnit(context, kcal)} / 100 ${favorite.unit}';
    final subtitle = [per100, favorite.portionLabel].whereType<String>().join(' · ');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: favorite.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  cacheManager: locator<CacheManager>(),
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  imageUrl: displayImageUrl(favorite.imageUrl!),
                  errorWidget: (context, url, error) => const Icon(Icons.star, color: Colors.amber),
                ),
              )
            : const Icon(Icons.star, color: Colors.amber),
        title: Text(
          favorite.brand == null || favorite.brand!.isEmpty ? favorite.name : '${favorite.name} (${favorite.brand})',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Semantics(
          identifier: 'favorites-edit',
          child: IconButton(tooltip: s.favoriteEditTitle, icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        ),
      ),
    );
  }
}
