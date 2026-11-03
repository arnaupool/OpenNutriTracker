import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/favorites/presentation/favorite_editor_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Star on a food's detail: filled when the food already is a favorite.
/// Tapping an empty star saves a local copy (macros per 100 g/ml, unit,
/// default portion from the product's serving, barcode, origin) and opens
/// the editor; tapping a filled one opens the editor of that favorite.
class FavoriteStarButton extends StatelessWidget {
  final MealEntity meal;
  final String identifier;

  /// Called when the editor closes, with the favorite as saved (null if it
  /// was deleted).
  final void Function(FavoriteFoodEntity? favorite)? onEdited;

  const FavoriteStarButton({super.key, required this.meal, this.identifier = 'meal-detail-favorite', this.onEdited});

  @override
  Widget build(BuildContext context) {
    final repo = locator<FavoriteFoodRepository>();
    return ListenableBuilder(
      listenable: repo.listenable(),
      builder: (context, _) {
        final favorite = repo.findForMeal(meal.code, meal.source.name);
        return Semantics(
          identifier: identifier,
          child: IconButton(
            tooltip: favorite == null ? S.of(context).favoriteAddTooltip : S.of(context).favoriteEditTitle,
            icon: Icon(
              favorite == null ? Icons.star_border : Icons.star,
              color: favorite == null ? null : Colors.amber,
            ),
            onPressed: () => _onPressed(context, repo, favorite),
          ),
        );
      },
    );
  }

  Future<void> _onPressed(BuildContext context, FavoriteFoodRepository repo, FavoriteFoodEntity? existing) async {
    final navigator = Navigator.of(context);
    var favorite = existing;
    if (favorite == null) {
      favorite = FavoriteFoodEntity.fromMeal(meal, id: IdGenerator.getUniqueID(), now: DateTime.now());
      await repo.save(favorite);
    }
    await navigator.pushNamed(
      NavigationOptions.favoriteEditorRoute,
      arguments: FavoriteEditorArguments(favoriteId: favorite.id),
    );
    onEdited?.call(repo.getById(favorite.id));
  }
}
