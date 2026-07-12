import 'package:json_annotation/json_annotation.dart';

part 'open_router_chat_completion_response_dto.g.dart';

@JsonSerializable()
class OpenRouterResponseMessageDTO {
  final String role;
  final String? content;

  OpenRouterResponseMessageDTO({required this.role, this.content});

  factory OpenRouterResponseMessageDTO.fromJson(Map<String, dynamic> json) =>
      _$OpenRouterResponseMessageDTOFromJson(json);

  Map<String, dynamic> toJson() => _$OpenRouterResponseMessageDTOToJson(this);
}

@JsonSerializable()
class OpenRouterChoiceDTO {
  final OpenRouterResponseMessageDTO message;

  OpenRouterChoiceDTO({required this.message});

  factory OpenRouterChoiceDTO.fromJson(Map<String, dynamic> json) =>
      _$OpenRouterChoiceDTOFromJson(json);

  Map<String, dynamic> toJson() => _$OpenRouterChoiceDTOToJson(this);
}

@JsonSerializable()
class OpenRouterChatCompletionResponseDTO {
  final List<OpenRouterChoiceDTO> choices;

  OpenRouterChatCompletionResponseDTO({required this.choices});

  factory OpenRouterChatCompletionResponseDTO.fromJson(
    Map<String, dynamic> json,
  ) => _$OpenRouterChatCompletionResponseDTOFromJson(json);

  Map<String, dynamic> toJson() =>
      _$OpenRouterChatCompletionResponseDTOToJson(this);
}
