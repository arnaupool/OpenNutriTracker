import 'package:equatable/equatable.dart';

/// FR-04: a nutrition-facts label as transcribed by the AI from a photo —
/// the "Big 7" fields most labels print (energy, carbs, fat, protein,
/// sugars, saturated fat, sodium) plus fibre, name, brand, and serving
/// size. Unlike [MagicFoodItemEntity] (FR-02/FR-03), every numeric value
/// here is already per-100g/100ml as printed on the label — there's no
/// "portion eaten" concept to scale from, and no confidence rating: the
/// model either reads the printed number or leaves it null.
class ScannedLabelEntity extends Equatable {
  final String? name;
  final String? brand;
  final String? servingSize;
  final double? kcal100;
  final double? carbs100;
  final double? fat100;
  final double? protein100;
  final double? sugars100;
  final double? saturatedFat100;
  final double? fiber100;
  final double? sodiumMg100;

  const ScannedLabelEntity({
    this.name,
    this.brand,
    this.servingSize,
    this.kcal100,
    this.carbs100,
    this.fat100,
    this.protein100,
    this.sugars100,
    this.saturatedFat100,
    this.fiber100,
    this.sodiumMg100,
  });

  @override
  List<Object?> get props => [
    name,
    brand,
    servingSize,
    kcal100,
    carbs100,
    fat100,
    protein100,
    sugars100,
    saturatedFat100,
    fiber100,
    sodiumMg100,
  ];
}
