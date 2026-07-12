import 'package:equatable/equatable.dart';

/// FR-03: how confident the model was in its estimate for one item, shown
/// as a badge on the Review meal screen (matches XMihura's reference).
enum MagicConfidence {
  low,
  medium,
  high;

  static MagicConfidence fromJson(dynamic value) {
    if (value is String) {
      for (final level in MagicConfidence.values) {
        if (level.name == value.trim().toLowerCase()) return level;
      }
    }
    return MagicConfidence.medium;
  }
}

/// FR-02/FR-03: one food item as estimated by the AI, for the full visible
/// portion (not per 100g) — the same "whatever's on the plate is one
/// serving" convention `QuickAddBottomSheet` already uses for user-typed
/// entries, so it round-trips through [MealNutrimentsEntity] unchanged.
/// [grams] is the model's estimated portion weight for that same portion,
/// letting the Review meal screen rescale kcal/macros when the user edits
/// the quantity.
class MagicFoodItemEntity extends Equatable {
  final String name;
  final double kcal;
  final double grams;
  final MagicConfidence confidence;
  final double? carbsG;
  final double? fatG;
  final double? proteinG;

  const MagicFoodItemEntity({
    required this.name,
    required this.kcal,
    required this.grams,
    this.confidence = MagicConfidence.medium,
    this.carbsG,
    this.fatG,
    this.proteinG,
  });

  @override
  List<Object?> get props =>
      [name, kcal, grams, confidence, carbsG, fatG, proteinG];
}
