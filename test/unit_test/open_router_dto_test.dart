import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_chat_completion_response_dto.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_models_response_dto.dart';

void main() {
  group('OpenRouterModelsResponseDTO', () {
    test('parses a catalog response with vision and text-only models', () {
      final json = {
        'data': [
          {
            'id': 'openai/gpt-4o',
            'name': 'OpenAI: GPT-4o',
            'description': 'A multimodal model',
            'context_length': 128000,
            'architecture': {
              'input_modalities': ['text', 'image'],
              'output_modalities': ['text'],
            },
          },
          {
            'id': 'meta-llama/llama-3-8b',
            'name': 'Meta: Llama 3 8B',
            'architecture': {
              'input_modalities': ['text'],
              'output_modalities': ['text'],
            },
          },
        ],
      };

      final response = OpenRouterModelsResponseDTO.fromJson(json);

      expect(response.data, hasLength(2));
      expect(response.data[0].id, 'openai/gpt-4o');
      expect(response.data[0].context_length, 128000);
      expect(
        response.data[0].architecture?.input_modalities,
        containsAll(['text', 'image']),
      );
      expect(response.data[1].description, isNull);
    });

    test('tolerates a model with no architecture field at all', () {
      final json = {
        'data': [
          {'id': 'bare/model', 'name': 'Bare Model'},
        ],
      };

      final response = OpenRouterModelsResponseDTO.fromJson(json);

      expect(response.data.single.architecture, isNull);
    });
  });

  group('OpenRouterChatCompletionResponseDTO', () {
    test('parses a single-choice chat completion response', () {
      final json = {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'Hello there'},
          },
        ],
      };

      final response = OpenRouterChatCompletionResponseDTO.fromJson(json);

      expect(response.choices, hasLength(1));
      expect(response.choices.first.message.role, 'assistant');
      expect(response.choices.first.message.content, 'Hello there');
    });
  });
}
