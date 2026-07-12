// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_router_chat_completion_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenRouterResponseMessageDTO _$OpenRouterResponseMessageDTOFromJson(
  Map<String, dynamic> json,
) => OpenRouterResponseMessageDTO(
  role: json['role'] as String,
  content: json['content'] as String?,
);

Map<String, dynamic> _$OpenRouterResponseMessageDTOToJson(
  OpenRouterResponseMessageDTO instance,
) => <String, dynamic>{'role': instance.role, 'content': instance.content};

OpenRouterChoiceDTO _$OpenRouterChoiceDTOFromJson(Map<String, dynamic> json) =>
    OpenRouterChoiceDTO(
      message: OpenRouterResponseMessageDTO.fromJson(
        json['message'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$OpenRouterChoiceDTOToJson(
  OpenRouterChoiceDTO instance,
) => <String, dynamic>{'message': instance.message};

OpenRouterChatCompletionResponseDTO
_$OpenRouterChatCompletionResponseDTOFromJson(Map<String, dynamic> json) =>
    OpenRouterChatCompletionResponseDTO(
      choices: (json['choices'] as List<dynamic>)
          .map((e) => OpenRouterChoiceDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OpenRouterChatCompletionResponseDTOToJson(
  OpenRouterChatCompletionResponseDTO instance,
) => <String, dynamic>{'choices': instance.choices};
