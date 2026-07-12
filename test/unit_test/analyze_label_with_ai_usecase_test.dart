import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/analyze_label_with_ai_usecase.dart';

class _FakeSendOpenRouterChatCompletionUsecase
    implements SendOpenRouterChatCompletionUsecase {
  String? response;
  Object? error;
  List<Map<String, dynamic>>? lastMessages;

  @override
  Future<String?> sendChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    lastMessages = messages;
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  late _FakeSendOpenRouterChatCompletionUsecase fakeSendUsecase;
  late AnalyzeLabelWithAiUsecase usecase;

  setUp(() {
    fakeSendUsecase = _FakeSendOpenRouterChatCompletionUsecase();
    usecase = AnalyzeLabelWithAiUsecase(fakeSendUsecase);
  });

  group('AnalyzeLabelWithAiUsecase.analyze', () {
    test('parses a well-formed label response', () async {
      fakeSendUsecase.response =
          '{"name": "Greek Yoghurt", "brand": "Fage", "servingSize": '
          '"170g", "kcal100": 97, "carbs100": 4, "fat100": 5, '
          '"protein100": 9, "sugars100": 4, "saturatedFat100": 3.3, '
          '"fiber100": 0, "sodiumMg100": 45}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      expect(result.name, 'Greek Yoghurt');
      expect(result.brand, 'Fage');
      expect(result.servingSize, '170g');
      expect(result.kcal100, 97);
      expect(result.carbs100, 4);
      expect(result.fat100, 5);
      expect(result.protein100, 9);
      expect(result.sugars100, 4);
      expect(result.saturatedFat100, 3.3);
      expect(result.fiber100, 0);
      expect(result.sodiumMg100, 45);
    });

    test('strips markdown code fences before parsing', () async {
      fakeSendUsecase.response =
          '```json\n{"name": "Apple sauce", "kcal100": 60}\n```';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      expect(result.name, 'Apple sauce');
      expect(result.kcal100, 60);
    });

    test('accepts numeric fields sent as strings', () async {
      fakeSendUsecase.response =
          '{"name": "Test", "kcal100": "97", "carbs100": "4.5"}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      expect(result.kcal100, 97);
      expect(result.carbs100, 4.5);
    });

    test('missing/unreadable fields become null rather than throwing', () async {
      fakeSendUsecase.response =
          '{"name": null, "brand": null, "servingSize": null, '
          '"kcal100": null, "carbs100": null, "fat100": null, '
          '"protein100": null, "sugars100": null, "saturatedFat100": null, '
          '"fiber100": null, "sodiumMg100": null}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      expect(result.name, isNull);
      expect(result.kcal100, isNull);
      expect(result.sodiumMg100, isNull);
    });

    test('blank string fields are normalized to null', () async {
      fakeSendUsecase.response =
          '{"name": "  ", "brand": "", "kcal100": 50}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      expect(result.name, isNull);
      expect(result.brand, isNull);
      expect(result.kcal100, 50);
    });

    test('throws LabelAnalysisException on malformed JSON', () async {
      fakeSendUsecase.response = 'this is not json at all';

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          base64Image: 'ZmFrZQ==',
        ),
        throwsA(isA<LabelAnalysisException>()),
      );
    });

    test('throws LabelAnalysisException on an empty response', () async {
      fakeSendUsecase.response = '';

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          base64Image: 'ZmFrZQ==',
        ),
        throwsA(isA<LabelAnalysisException>()),
      );
    });

    test('wraps a network/API failure in LabelAnalysisException', () async {
      fakeSendUsecase.error = Exception('network down');

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          base64Image: 'ZmFrZQ==',
        ),
        throwsA(isA<LabelAnalysisException>()),
      );
    });

    test('always sends a vision message with the image', () async {
      fakeSendUsecase.response = '{"name": "Test", "kcal100": 50}';

      await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        base64Image: 'ZmFrZQ==',
      );

      final userMessage = fakeSendUsecase.lastMessages!.last;
      expect(userMessage['content'], isA<List>());
      final content = userMessage['content'] as List;
      expect(content.any((part) => part['type'] == 'image_url'), isTrue);
    });
  });
}
