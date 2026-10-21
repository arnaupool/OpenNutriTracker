import 'package:json_annotation/json_annotation.dart';

part 'fdc_food_nutriment_dto.g.dart';

/// One entry of `foodNutrients` in a USDA FoodData Central search response
/// (https://api.nal.usda.gov/fdc/v1/foods/search). The API identifies a
/// nutrient both by [nutrientId] (e.g. 1003 protein) and by its legacy SR
/// [nutrientNumber] (e.g. "303" iron); FDCConst mixes both, so lookups match
/// either.
@JsonSerializable()
class FDCFoodNutrimentDTO {
  final int? nutrientId;
  final String? nutrientNumber;
  final double? value;

  FDCFoodNutrimentDTO({
    required this.nutrientId,
    this.nutrientNumber,
    required this.value,
  });

  /// Whether this entry is the nutrient FDCConst identifies as [code].
  bool matches(int code) =>
      nutrientId == code || int.tryParse(nutrientNumber ?? '') == code;

  factory FDCFoodNutrimentDTO.fromJson(Map<String, dynamic> json) =>
      _$FDCFoodNutrimentDTOFromJson(json);

  Map<String, dynamic> toJson() => _$FDCFoodNutrimentDTOToJson(this);
}
