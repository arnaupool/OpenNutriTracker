import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_model_dto.dart';

class OpenRouterModelEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final bool supportsImages;

  const OpenRouterModelEntity({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    required this.supportsImages,
  });

  factory OpenRouterModelEntity.fromDTO(OpenRouterModelDTO dto) =>
      OpenRouterModelEntity(
        id: dto.id,
        name: dto.name,
        description: dto.description,
        contextLength: dto.context_length,
        supportsImages:
            dto.architecture?.input_modalities?.contains('image') ?? false,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    contextLength,
    supportsImages,
  ];
}
