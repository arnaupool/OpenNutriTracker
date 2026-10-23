import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';

class PlanTotals {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const PlanTotals(this.kcal, this.protein, this.carbs, this.fat);

  static const zero = PlanTotals(0, 0, 0, 0);

  PlanTotals operator +(PlanTotals other) =>
      PlanTotals(kcal + other.kcal, protein + other.protein, carbs + other.carbs, fat + other.fat);
}

class ShoppingItem {
  final String name;
  final double amount;
  final String unit;

  const ShoppingItem(this.name, this.amount, this.unit);
}

/// Totals and the shopping list for a set of planned entries (FAS-04).
class MealPlanCalc {
  /// Nutrients of one entry: per-100 values of its snapshot times grams.
  static PlanTotals totalsOf(MealPlanEntryDBO entry) {
    final n = entry.meal.nutriments;
    final factor = entry.amount / 100;
    return PlanTotals(
      (n.energyKcal100 ?? 0) * factor,
      (n.proteins100 ?? 0) * factor,
      (n.carbohydrates100 ?? 0) * factor,
      (n.fat100 ?? 0) * factor,
    );
  }

  static PlanTotals totals(Iterable<MealPlanEntryDBO> entries) =>
      entries.fold(PlanTotals.zero, (sum, e) => sum + totalsOf(e));

  /// What to buy for [entries]: a planned recipe is broken down into its
  /// ingredients, scaled from the recipe's total weight to the planned
  /// grams; anything else is bought as itself. Same food names add up
  /// (case-insensitive); amounts stay per unit, so grams and millilitres
  /// are never summed together. Entries already logged are still listed:
  /// eating it doesn't mean it was not bought.
  static List<ShoppingItem> shoppingList(Iterable<MealPlanEntryDBO> entries, Map<String, RecipeDBO> recipesById) {
    final totals = <String, ({String name, double amount, String unit})>{};
    void add(String? rawName, double amount, String unit) {
      final name = (rawName ?? '').trim();
      if (name.isEmpty || amount <= 0) return;
      final key = '${name.toLowerCase()}|$unit';
      final existing = totals[key];
      totals[key] = (name: existing?.name ?? name, amount: (existing?.amount ?? 0) + amount, unit: unit);
    }

    for (final e in entries) {
      final recipe = e.meal.source == MealSourceDBO.recipe ? recipesById[e.meal.code] : null;
      if (recipe != null && recipe.totalWeightG > 0) {
        final factor = e.amount / recipe.totalWeightG;
        for (final ingredient in recipe.ingredients) {
          add(ingredient.snapshotMeal.name, ingredient.convertedAmountG * factor, 'g');
        }
      } else {
        add(e.meal.name, e.amount, e.unit);
      }
    }
    final items = [for (final t in totals.values) ShoppingItem(t.name, t.amount, t.unit)];
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }
}
