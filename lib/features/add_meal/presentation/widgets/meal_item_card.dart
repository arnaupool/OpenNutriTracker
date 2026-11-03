import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/util/food_emoji_resolver.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/utils/off_image_url.dart';

class MealItemCard extends StatelessWidget {
  final DateTime day;
  final AddMealType addMealType;
  final MealEntity mealEntity;
  final bool usesImperialUnits;

  /// Set when the card stands for a favorite: it is drawn with a star and
  /// opens the detail with the favorite's default portion.
  final FavoriteFoodEntity? favorite;

  /// When set, tapping the card hands the food to this callback instead of
  /// opening its detail (choosing a food to copy as a favorite).
  final void Function(MealEntity meal)? onPick;

  const MealItemCard({
    super.key,
    required this.day,
    required this.mealEntity,
    required this.addMealType,
    required this.usesImperialUnits,
    this.favorite,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final isRecipe = mealEntity.source == MealSourceEntity.recipe;
    // Colored emoji is reserved for FDC base-food items where the head
    // noun reliably identifies the food ("Milk, fluid, nonfat..." → milk).
    // OFF products are branded, so a head-noun match would often be
    // misleading; they keep the outline icon as a placeholder.
    final emoji = (mealEntity.thumbnailImageUrl == null && mealEntity.source == MealSourceEntity.fdc)
        ? resolveFoodEmoji(mealEntity.name)
        : null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isRecipe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
          width: isRecipe ? 1.5 : 1.0,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Center(
            child: ListTile(
              leading: mealEntity.thumbnailImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        cacheManager: locator<CacheManager>(),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        // Decode at the actual display size instead of the
                        // source image's full resolution — cheaper decode
                        // and less memory pressure while a results list is
                        // streaming several thumbnails in at once.
                        memCacheWidth: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
                        memCacheHeight: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
                        imageUrl: displayImageUrl(mealEntity.thumbnailImageUrl ?? ""),
                        placeholder: (context, url) => const Center(
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.restaurant_outlined),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        color: isRecipe
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: emoji != null
                            ? ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 32)))
                            : Icon(
                                isRecipe ? Icons.menu_book : Icons.restaurant_outlined,
                                color: isRecipe ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                              ),
                      ),
                    ),
              title: AutoSizeText.rich(
                TextSpan(
                  text: mealEntity.name ?? "?",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  children: [
                    TextSpan(
                      text: ' ${mealEntity.brands ?? ""}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: isRecipe
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            S.of(context).additionalInfoLabelRecipe,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    )
                  : _detailsLine(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (favorite != null) const Icon(Icons.star, color: Colors.amber, key: Key('favorite-star')),
                  IconButton(
                    style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                    icon: const Icon(Icons.add_outlined),
                    onPressed: () => _onItemPressed(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        onTap: () => _onItemPressed(context),
      ),
    );
  }

  /// Package quantity, then energy and protein per 100 g (or ml).
  Widget _detailsLine(BuildContext context) {
    final quantity = double.tryParse(mealEntity.mealQuantity ?? '');
    final kcal = mealEntity.nutriments.energyKcal100;
    final protein = mealEntity.nutriments.proteins100;
    final basis = mealEntity.mealUnit == 'ml' ? 'ml' : 'g';
    final parts = <String>[
      if (kcal != null) '${kcal.round()} kcal / 100 $basis',
      if (protein != null) '${_trimmed(protein)} g ${S.of(context).proteinLabel}',
    ];
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quantity != null)
          MealValueUnitText(value: quantity, meal: mealEntity, usesImperialUnits: usesImperialUnits, textStyle: style),
        if (parts.isNotEmpty) Text(parts.join(' · '), style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  static String _trimmed(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void _onItemPressed(BuildContext context) {
    final onPick = this.onPick;
    if (onPick != null) {
      onPick(mealEntity);
      return;
    }
    Navigator.of(context).pushNamed(
      NavigationOptions.mealDetailRoute,
      arguments: MealDetailScreenArguments(
        mealEntity,
        addMealType.getIntakeType(),
        day,
        usesImperialUnits,
        favorite: favorite,
      ),
    );
  }
}
