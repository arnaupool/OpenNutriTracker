// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fdc_food_nutriment_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FDCFoodNutrimentDTO _$FDCFoodNutrimentDTOFromJson(Map<String, dynamic> json) =>
    FDCFoodNutrimentDTO(
      nutrientId: (json['nutrientId'] as num?)?.toInt(),
      nutrientNumber: json['nutrientNumber'] as String?,
      value: (json['value'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$FDCFoodNutrimentDTOToJson(
  FDCFoodNutrimentDTO instance,
) => <String, dynamic>{
  'nutrientId': instance.nutrientId,
  'nutrientNumber': instance.nutrientNumber,
  'value': instance.value,
};
