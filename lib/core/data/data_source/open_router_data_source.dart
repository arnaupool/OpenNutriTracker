import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_chat_completion_response_dto.dart';
import 'package:opennutritracker/core/data/dto/open_router/open_router_models_response_dto.dart';
import 'package:opennutritracker/core/utils/retry_util.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class OpenRouterDataSource {
  static const _baseUrl = 'https://openrouter.ai/api/v1';
  static const _timeoutDuration = Duration(seconds: 30);
  final log = Logger('OpenRouterDataSource');

  /// The model catalog is a public endpoint — no API key required.
  Future<OpenRouterModelsResponseDTO> fetchModels() async {
    try {
      return await withRetry(() async {
        final response = await http
            .get(Uri.parse('$_baseUrl/models'))
            .timeout(_timeoutDuration);
        if (response.statusCode == 200) {
          return OpenRouterModelsResponseDTO.fromJson(
            jsonDecode(response.body),
          );
        }
        log.warning('Failed OpenRouter models call: ${response.statusCode}');
        throw Exception('OpenRouter HTTP ${response.statusCode}');
      });
    } catch (exception, stacktrace) {
      log.severe('Exception while fetching OpenRouter models $exception');
      Sentry.captureException(exception, stackTrace: stacktrace);
      return Future.error(exception);
    }
  }

  Future<OpenRouterChatCompletionResponseDTO> sendChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      return await withRetry(() async {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/chat/completions'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'model': model, 'messages': messages}),
            )
            .timeout(_timeoutDuration);
        if (response.statusCode == 200) {
          return OpenRouterChatCompletionResponseDTO.fromJson(
            jsonDecode(response.body),
          );
        }
        log.warning(
          'Failed OpenRouter chat completion call: ${response.statusCode} '
          '${response.body}',
        );
        throw Exception('OpenRouter HTTP ${response.statusCode}');
      });
    } catch (exception, stacktrace) {
      log.severe(
        'Exception while sending OpenRouter chat completion $exception',
      );
      Sentry.captureException(exception, stackTrace: stacktrace);
      return Future.error(exception);
    }
  }
}
