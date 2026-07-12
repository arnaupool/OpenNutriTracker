// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_router_models_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenRouterModelsResponseDTO _$OpenRouterModelsResponseDTOFromJson(
  Map<String, dynamic> json,
) => OpenRouterModelsResponseDTO(
  data: (json['data'] as List<dynamic>)
      .map((e) => OpenRouterModelDTO.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OpenRouterModelsResponseDTOToJson(
  OpenRouterModelsResponseDTO instance,
) => <String, dynamic>{'data': instance.data};
