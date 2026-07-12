import 'package:opennutritracker/core/data/data_source/open_router_data_source.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';

class OpenRouterRepository {
  final OpenRouterDataSource _openRouterDataSource;

  OpenRouterRepository(this._openRouterDataSource);

  Future<List<OpenRouterModelEntity>> getAvailableModels() async {
    final response = await _openRouterDataSource.fetchModels();
    return response.data.map(OpenRouterModelEntity.fromDTO).toList();
  }

  /// Sends a chat completion request and returns the assistant's reply text,
  /// or null if the response carried no message content.
  Future<String?> sendChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    final response = await _openRouterDataSource.sendChatCompletion(
      apiKey: apiKey,
      model: model,
      messages: messages,
    );
    if (response.choices.isEmpty) return null;
    return response.choices.first.message.content;
  }

  /// Builds a plain text message in OpenAI Chat Completions format.
  static Map<String, dynamic> textMessage({
    required String role,
    required String text,
  }) => {'role': role, 'content': text};

  /// Builds a multi-part message combining text with a base64-encoded image,
  /// for vision-capable models (OpenAI Chat Completions image content
  /// format). [mimeType] defaults to JPEG, the common case for a camera
  /// capture.
  static Map<String, dynamic> visionMessage({
    required String role,
    required String text,
    required String base64Image,
    String mimeType = 'image/jpeg',
  }) => {
    'role': role,
    'content': [
      {'type': 'text', 'text': text},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
      },
    ],
  };
}
