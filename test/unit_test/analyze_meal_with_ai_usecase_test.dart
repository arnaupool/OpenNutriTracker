import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/repository/open_router_repository.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/analyze_meal_with_ai_usecase.dart';

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
  late AnalyzeMealWithAiUsecase usecase;

  setUp(() {
    fakeSendUsecase = _FakeSendOpenRouterChatCompletionUsecase();
    usecase = AnalyzeMealWithAiUsecase(fakeSendUsecase);
  });

  group('AnalyzeMealWithAiUsecase.analyze', () {
    test('parses a well-formed single-item JSON response', () async {
      fakeSendUsecase.response =
          '{"items": [{"name": "Grilled chicken breast", "kcal": 250, '
          '"carbs_g": 0, "fat_g": 6, "protein_g": 47}]}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
        description: 'a piece of chicken',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Grilled chicken breast');
      expect(result.single.kcal, 250);
      expect(result.single.carbsG, 0);
      expect(result.single.fatG, 6);
      expect(result.single.proteinG, 47);
    });

    test('parses a multi-item meal-breakdown response', () async {
      fakeSendUsecase.response =
          '{"items": ['
          '{"name": "Rice", "kcal": 200, "carbs_g": 45, "fat_g": 0.5, "protein_g": 4},'
          '{"name": "Chicken", "kcal": 250, "carbs_g": 0, "fat_g": 6, "protein_g": 47}'
          ']}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: true,
        description: 'rice and chicken',
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Rice');
      expect(result[1].name, 'Chicken');
    });

    test('strips markdown code fences before parsing', () async {
      fakeSendUsecase.response =
          '```json\n{"items": [{"name": "Apple", "kcal": 95}]}\n```';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );

      expect(result.single.name, 'Apple');
      expect(result.single.kcal, 95);
    });

    test('accepts numeric fields sent as strings', () async {
      fakeSendUsecase.response =
          '{"items": [{"name": "Apple", "kcal": "95", "carbs_g": "25"}]}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );

      expect(result.single.kcal, 95);
      expect(result.single.carbsG, 25);
    });

    test('drops items missing a name or kcal instead of throwing', () async {
      fakeSendUsecase.response =
          '{"items": ['
          '{"name": "Valid", "kcal": 100},'
          '{"kcal": 200},'
          '{"name": "No kcal"}'
          ']}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: true,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Valid');
    });

    test('returns an empty list when the model found no food', () async {
      fakeSendUsecase.response = '{"items": []}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );

      expect(result, isEmpty);
    });

    test('throws MagicAnalysisException on malformed JSON', () async {
      fakeSendUsecase.response = 'this is not json at all';

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          mealBreakdown: false,
        ),
        throwsA(isA<MagicAnalysisException>()),
      );
    });

    test('throws MagicAnalysisException on an empty response', () async {
      fakeSendUsecase.response = '';

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          mealBreakdown: false,
        ),
        throwsA(isA<MagicAnalysisException>()),
      );
    });

    test('wraps a network/API failure in MagicAnalysisException', () async {
      fakeSendUsecase.error = Exception('network down');

      expect(
        () => usecase.analyze(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          mealBreakdown: false,
        ),
        throwsA(isA<MagicAnalysisException>()),
      );
    });

    test('sends a vision message when an image is provided', () async {
      fakeSendUsecase.response = '{"items": [{"name": "Apple", "kcal": 95}]}';

      await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
        base64Image: 'ZmFrZQ==',
      );

      final userMessage = fakeSendUsecase.lastMessages!.last;
      expect(userMessage['content'], isA<List>());
      final content = userMessage['content'] as List;
      expect(content.any((part) => part['type'] == 'image_url'), isTrue);
    });

    test('sends a plain text message when no image is provided', () async {
      fakeSendUsecase.response = '{"items": [{"name": "Apple", "kcal": 95}]}';

      await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
        description: 'an apple',
      );

      final userMessage = fakeSendUsecase.lastMessages!.last;
      expect(userMessage['content'], isA<String>());
    });

    test('parses grams and confidence from a well-formed response', () async {
      fakeSendUsecase.response =
          '{"items": [{"name": "Sliced Beef", "kcal": 275, "grams": 110, '
          '"confidence": "medium", "carbs_g": 0, "fat_g": 17, "protein_g": 28}]}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );

      expect(result.single.grams, 110);
      expect(result.single.confidence, MagicConfidence.medium);
    });

    test('defaults grams to 100 when missing or non-positive', () async {
      fakeSendUsecase.response =
          '{"items": ['
          '{"name": "No grams", "kcal": 100},'
          '{"name": "Zero grams", "kcal": 100, "grams": 0},'
          '{"name": "Negative grams", "kcal": 100, "grams": -5}'
          ']}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: true,
      );

      expect(result, hasLength(3));
      expect(result.every((item) => item.grams == 100), isTrue);
    });

    test('defaults confidence to medium when missing or unrecognized', () async {
      fakeSendUsecase.response =
          '{"items": ['
          '{"name": "No confidence", "kcal": 100},'
          '{"name": "Weird confidence", "kcal": 100, "confidence": "very sure"}'
          ']}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: true,
      );

      expect(result, hasLength(2));
      expect(
        result.every((item) => item.confidence == MagicConfidence.medium),
        isTrue,
      );
    });

    test('confidence parsing is case-insensitive', () async {
      fakeSendUsecase.response =
          '{"items": [{"name": "Item", "kcal": 100, "confidence": "HIGH"}]}';

      final result = await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );

      expect(result.single.confidence, MagicConfidence.high);
    });

    test('meal-breakdown prompt differs from single-item prompt', () async {
      fakeSendUsecase.response = '{"items": []}';

      await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: true,
      );
      final breakdownSystemPrompt =
          fakeSendUsecase.lastMessages!.first['content'] as String;

      await usecase.analyze(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        mealBreakdown: false,
      );
      final singleItemSystemPrompt =
          fakeSendUsecase.lastMessages!.first['content'] as String;

      expect(breakdownSystemPrompt, isNot(equals(singleItemSystemPrompt)));
    });
  });

  group(
    'OpenRouterRepository.visionMessage (sanity check for the usecase)',
    () {
      test('embeds the base64 image as a data URL', () {
        final message = OpenRouterRepository.visionMessage(
          role: 'user',
          text: 'test',
          base64Image: 'ZmFrZQ==',
        );
        final content = message['content'] as List;
        final imagePart = content.firstWhere((p) => p['type'] == 'image_url');
        expect(imagePart['image_url']['url'], contains('base64,ZmFrZQ=='));
      });
    },
  );
}
