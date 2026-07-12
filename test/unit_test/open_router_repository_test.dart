import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/open_router_data_source.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_chat_completion_response_dto.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_model_dto.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_models_response_dto.dart';
import 'package:opennutritracker/core/data/repository/open_router_repository.dart';

class _FakeOpenRouterDataSource extends OpenRouterDataSource {
  OpenRouterModelsResponseDTO? modelsResponse;
  OpenRouterChatCompletionResponseDTO? chatResponse;
  Map<String, dynamic>? lastRequestHeaders;
  String? lastApiKey;
  String? lastModel;
  List<Map<String, dynamic>>? lastMessages;

  @override
  Future<OpenRouterModelsResponseDTO> fetchModels() async {
    return modelsResponse!;
  }

  @override
  Future<OpenRouterChatCompletionResponseDTO> sendChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    lastApiKey = apiKey;
    lastModel = model;
    lastMessages = messages;
    return chatResponse!;
  }
}

void main() {
  group('OpenRouterRepository.getAvailableModels', () {
    test('maps DTOs to entities and derives supportsImages from '
        'input_modalities', () async {
      final dataSource = _FakeOpenRouterDataSource()
        ..modelsResponse = OpenRouterModelsResponseDTO(
          data: [
            OpenRouterModelDTO(
              id: 'openai/gpt-4o',
              name: 'GPT-4o',
              context_length: 128000,
              architecture: OpenRouterModelArchitectureDTO(
                input_modalities: ['text', 'image'],
              ),
            ),
            OpenRouterModelDTO(id: 'text-only/model', name: 'Text Only'),
          ],
        );
      final repository = OpenRouterRepository(dataSource);

      final models = await repository.getAvailableModels();

      expect(models, hasLength(2));
      expect(models[0].supportsImages, isTrue);
      expect(models[0].contextLength, 128000);
      expect(models[1].supportsImages, isFalse);
    });
  });

  group('OpenRouterRepository.sendChatCompletion', () {
    test('returns the first choice message content', () async {
      final dataSource = _FakeOpenRouterDataSource()
        ..chatResponse = OpenRouterChatCompletionResponseDTO(
          choices: [
            OpenRouterChoiceDTO(
              message: OpenRouterResponseMessageDTO(
                role: 'assistant',
                content: 'It looks like grilled chicken.',
              ),
            ),
          ],
        );
      final repository = OpenRouterRepository(dataSource);

      final reply = await repository.sendChatCompletion(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        messages: [
          OpenRouterRepository.textMessage(role: 'user', text: 'What is this?'),
        ],
      );

      expect(reply, 'It looks like grilled chicken.');
      expect(dataSource.lastApiKey, 'sk-or-test');
      expect(dataSource.lastModel, 'openai/gpt-4o');
    });

    test('returns null when the response has no choices', () async {
      final dataSource = _FakeOpenRouterDataSource()
        ..chatResponse = OpenRouterChatCompletionResponseDTO(choices: []);
      final repository = OpenRouterRepository(dataSource);

      final reply = await repository.sendChatCompletion(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        messages: [],
      );

      expect(reply, isNull);
    });
  });

  group('OpenRouterRepository message builders', () {
    test('textMessage builds a plain string-content message', () {
      final message = OpenRouterRepository.textMessage(
        role: 'user',
        text: 'Hello',
      );

      expect(message, {'role': 'user', 'content': 'Hello'});
    });

    test('visionMessage builds a multi-part message with a data URL image', () {
      final message = OpenRouterRepository.visionMessage(
        role: 'user',
        text: 'What is in this photo?',
        base64Image: 'ZmFrZWJhc2U2NA==',
      );

      expect(message['role'], 'user');
      final content = message['content'] as List;
      expect(content, hasLength(2));
      expect(content[0], {'type': 'text', 'text': 'What is in this photo?'});
      expect(content[1]['type'], 'image_url');
      expect(
        content[1]['image_url']['url'],
        'data:image/jpeg;base64,ZmFrZWJhc2U2NA==',
      );
    });
  });
}
