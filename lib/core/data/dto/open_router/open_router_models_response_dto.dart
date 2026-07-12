import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_model_dto.dart';

part 'open_router_models_response_dto.g.dart';

@JsonSerializable()
class OpenRouterModelsResponseDTO {
  final List<OpenRouterModelDTO> data;

  OpenRouterModelsResponseDTO({required this.data});

  factory OpenRouterModelsResponseDTO.fromJson(Map<String, dynamic> json) =>
      _$OpenRouterModelsResponseDTOFromJson(json);

  Map<String, dynamic> toJson() => _$OpenRouterModelsResponseDTOToJson(this);
}
