// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_router_model_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenRouterModelArchitectureDTO _$OpenRouterModelArchitectureDTOFromJson(
  Map<String, dynamic> json,
) => OpenRouterModelArchitectureDTO(
  input_modalities: (json['input_modalities'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  output_modalities: (json['output_modalities'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$OpenRouterModelArchitectureDTOToJson(
  OpenRouterModelArchitectureDTO instance,
) => <String, dynamic>{
  'input_modalities': instance.input_modalities,
  'output_modalities': instance.output_modalities,
};

OpenRouterModelDTO _$OpenRouterModelDTOFromJson(Map<String, dynamic> json) =>
    OpenRouterModelDTO(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      context_length: (json['context_length'] as num?)?.toInt(),
      architecture: json['architecture'] == null
          ? null
          : OpenRouterModelArchitectureDTO.fromJson(
              json['architecture'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$OpenRouterModelDTOToJson(OpenRouterModelDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'context_length': instance.context_length,
      'architecture': instance.architecture,
    };
