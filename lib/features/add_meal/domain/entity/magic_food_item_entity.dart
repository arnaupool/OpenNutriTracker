import 'package:equatable/equatable.dart';

/// FR-02: one food item as estimated by the AI, for the full visible
/// portion (not per 100g) — the same "whatever's on the plate is one
/// serving" convention `QuickAddBottomSheet` already uses for user-typed
/// entries, so it round-trips through [MealNutrimentsEntity] unchanged.
class MagicFoodItemEntity extends Equatable {
  final String name;
  final double kcal;
  final double? carbsG;
  final double? fatG;
  final double? proteinG;

  const MagicFoodItemEntity({
    required this.name,
    required this.kcal,
    this.carbsG,
    this.fatG,
    this.proteinG,
  });

  @override
  List<Object?> get props => [name, kcal, carbsG, fatG, proteinG];
}
