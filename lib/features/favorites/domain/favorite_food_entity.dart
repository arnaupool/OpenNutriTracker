import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/favorites/data/favorite_food_dbo.dart';

/// Prefix of the meal code of a favorite that has no barcode.
const String favoriteCodePrefix = 'fav:';

/// [base] with its four main macros replaced (null clears one); micronutrients
/// and the rest are kept.
MealNutrimentsEntity nutrimentsWithMacros(
  MealNutrimentsEntity base, {
  required double? kcal,
  required double? carbs,
  required double? fat,
  required double? protein,
}) => MealNutrimentsEntity(
  energyKcal100: kcal,
  carbohydrates100: carbs,
  fat100: fat,
  proteins100: protein,
  sugars100: base.sugars100,
  saturatedFat100: base.saturatedFat100,
  fiber100: base.fiber100,
  monounsaturatedFat100: base.monounsaturatedFat100,
  polyunsaturatedFat100: base.polyunsaturatedFat100,
  transFat100: base.transFat100,
  cholesterol100: base.cholesterol100,
  sodium100: base.sodium100,
  potassium100: base.potassium100,
  magnesium100: base.magnesium100,
  calcium100: base.calcium100,
  iron100: base.iron100,
  zinc100: base.zinc100,
  phosphorus100: base.phosphorus100,
  vitaminA100: base.vitaminA100,
  vitaminC100: base.vitaminC100,
  vitaminD100: base.vitaminD100,
  vitaminB6100: base.vitaminB6100,
  vitaminB12100: base.vitaminB12100,
  niacin100: base.niacin100,
);

/// A favorite food as the UI sees it. See [FavoriteFoodDBO].
class FavoriteFoodEntity extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final MealNutrimentsEntity nutriments;
  final String unit;
  final String? portionName;
  final double? portionQuantity;
  final List<String> barcodes;
  final String? originSource;
  final String? originId;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const FavoriteFoodEntity({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.nutriments,
    this.unit = 'g',
    this.portionName,
    this.portionQuantity,
    this.barcodes = const [],
    this.originSource,
    this.originId,
    required this.createdAt,
    required this.modifiedAt,
  });

  bool get isLiquid => unit == 'ml';

  /// The default portion as shown to the user ("Glass, 250 ml"), or null.
  String? get portionLabel {
    final qty = portionQuantity;
    if (qty == null) return null;
    final amount = qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
    final label = '$amount $unit';
    final n = portionName?.trim();
    return n == null || n.isEmpty ? label : '$n, $label';
  }

  /// [clearPortion] drops the default portion; [clearBrand] drops the brand.
  FavoriteFoodEntity copyWith({
    String? name,
    String? brand,
    bool clearBrand = false,
    String? imageUrl,
    MealNutrimentsEntity? nutriments,
    String? unit,
    String? portionName,
    double? portionQuantity,
    bool clearPortion = false,
    List<String>? barcodes,
    DateTime? modifiedAt,
  }) => FavoriteFoodEntity(
    id: id,
    name: name ?? this.name,
    brand: clearBrand ? null : brand ?? this.brand,
    imageUrl: imageUrl ?? this.imageUrl,
    nutriments: nutriments ?? this.nutriments,
    unit: unit ?? this.unit,
    portionName: clearPortion ? null : portionName ?? this.portionName,
    portionQuantity: clearPortion ? null : portionQuantity ?? this.portionQuantity,
    barcodes: barcodes ?? this.barcodes,
    originSource: originSource,
    originId: originId,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  factory FavoriteFoodEntity.fromDBO(FavoriteFoodDBO dbo) => FavoriteFoodEntity(
    id: dbo.id,
    name: dbo.name,
    brand: dbo.brand,
    imageUrl: dbo.imageUrl,
    nutriments: MealNutrimentsEntity.fromMealNutrimentsDBO(dbo.nutriments),
    unit: dbo.unit,
    portionName: dbo.portionName,
    portionQuantity: dbo.portionQuantity,
    barcodes: List.unmodifiable(dbo.barcodes),
    originSource: dbo.originSource,
    originId: dbo.originId,
    createdAt: dbo.createdAt,
    modifiedAt: dbo.modifiedAt,
  );

  FavoriteFoodDBO toDBO() => FavoriteFoodDBO(
    id: id,
    name: name,
    brand: brand,
    imageUrl: imageUrl,
    nutriments: MealNutrimentsDBO.fromProductNutrimentsEntity(nutriments),
    unit: unit,
    portionName: portionName,
    portionQuantity: portionQuantity,
    barcodes: barcodes,
    originSource: originSource,
    originId: originId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );

  /// A copy of [meal] as a favorite: macros per 100 g/ml, the unit, a default
  /// portion taken from the product's serving size when it has one, and the
  /// scanned or known barcode. [barcode] overrides the product code (a scan).
  factory FavoriteFoodEntity.fromMeal(MealEntity meal, {required String id, required DateTime now, String? barcode}) {
    final unit = meal.isLiquid || meal.servingUnit == 'ml' ? 'ml' : 'g';
    final code = barcode ?? meal.code;
    final isBarcode =
        barcode != null ||
        (code != null &&
            RegExp(r'^\d{8,14}$').hasMatch(code) &&
            (meal.source == MealSourceEntity.off || meal.source == MealSourceEntity.custom));
    return FavoriteFoodEntity(
      id: id,
      name: meal.name ?? '',
      brand: meal.brands,
      imageUrl: meal.mainImageUrl ?? meal.thumbnailImageUrl,
      nutriments: meal.nutriments,
      unit: unit,
      portionName: meal.servingQuantity == null ? null : _portionNameOf(meal),
      portionQuantity: meal.servingQuantity,
      barcodes: [if (isBarcode) code!],
      originSource: meal.source == MealSourceEntity.unknown ? null : meal.source.name,
      originId: meal.code,
      createdAt: now,
      modifiedAt: now,
    );
  }

  static String? _portionNameOf(MealEntity meal) {
    final size = meal.servingSize?.trim();
    if (size == null || size.isEmpty) return null;
    // A size like "250 ml" is just the quantity again; keep only real names.
    if (RegExp(r'^[\d.,\s]*(g|ml|l|cl|dl|oz|fl oz)?$', caseSensitive: false).hasMatch(size)) return null;
    return size;
  }

  /// The food as a meal for the existing logging flow. The meal code is the
  /// first barcode, or `fav:<id>`; the base is 100 [unit] with the default
  /// portion as its serving.
  MealEntity toMealEntity() => MealEntity(
    code: barcodes.isNotEmpty ? barcodes.first : '$favoriteCodePrefix$id',
    name: name,
    brands: brand,
    thumbnailImageUrl: imageUrl,
    mainImageUrl: imageUrl,
    url: null,
    mealQuantity: '100',
    mealUnit: unit,
    servingQuantity: portionQuantity,
    servingUnit: portionQuantity == null ? null : unit,
    servingSize: portionQuantity == null ? null : portionLabel,
    nutriments: nutriments,
    source: MealSourceEntity.custom,
    detailed: true,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    brand,
    imageUrl,
    nutriments,
    unit,
    portionName,
    portionQuantity,
    barcodes,
    originSource,
    originId,
    modifiedAt,
  ];
}
