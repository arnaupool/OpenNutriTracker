// ignore_for_file: non_constant_identifier_names
import 'package:json_annotation/json_annotation.dart';

part 'open_router_model_dto.g.dart';

@JsonSerializable()
class OpenRouterModelArchitectureDTO {
  final List<String>? input_modalities;
  final List<String>? output_modalities;

  OpenRouterModelArchitectureDTO({
    this.input_modalities,
    this.output_modalities,
  });

  factory OpenRouterModelArchitectureDTO.fromJson(Map<String, dynamic> json) =>
      _$OpenRouterModelArchitectureDTOFromJson(json);

  Map<String, dynamic> toJson() => _$OpenRouterModelArchitectureDTOToJson(this);
}

@JsonSerializable()
class OpenRouterModelDTO {
  final String id;
  final String name;
  final String? description;
  final int? context_length;
  final OpenRouterModelArchitectureDTO? architecture;

  OpenRouterModelDTO({
    required this.id,
    required this.name,
    this.description,
    this.context_length,
    this.architecture,
  });

  factory OpenRouterModelDTO.fromJson(Map<String, dynamic> json) =>
      _$OpenRouterModelDTOFromJson(json);

  Map<String, dynamic> toJson() => _$OpenRouterModelDTOToJson(this);
}
