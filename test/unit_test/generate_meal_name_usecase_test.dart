import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/generate_meal_name_usecase.dart';

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
  late GenerateMealNameUsecase usecase;

  setUp(() {
    fakeSendUsecase = _FakeSendOpenRouterChatCompletionUsecase();
    usecase = GenerateMealNameUsecase(fakeSendUsecase);
  });

  group('GenerateMealNameUsecase.generate', () {
    test('returns the model reply as-is when already clean', () async {
      fakeSendUsecase.response = 'Beef Noodle Stir-Fry';

      final result = await usecase.generate(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        itemNames: ['Sliced Beef', 'Wide Rice Noodles'],
      );

      expect(result, 'Beef Noodle Stir-Fry');
    });

    test('strips wrapping quotes some models add', () async {
      fakeSendUsecase.response = '"Beef Noodle Stir-Fry"';

      final result = await usecase.generate(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        itemNames: ['Sliced Beef'],
      );

      expect(result, 'Beef Noodle Stir-Fry');
    });

    test('strips a trailing period', () async {
      fakeSendUsecase.response = 'Beef Noodle Stir-Fry.';

      final result = await usecase.generate(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        itemNames: ['Sliced Beef'],
      );

      expect(result, 'Beef Noodle Stir-Fry');
    });

    test('returns empty immediately for an empty item list without '
        'calling the API', () async {
      final result = await usecase.generate(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        itemNames: [],
      );

      expect(result, '');
      expect(fakeSendUsecase.lastMessages, isNull);
    });

    test('sends the joined item names as the user message', () async {
      fakeSendUsecase.response = 'Beef Noodle Stir-Fry';

      await usecase.generate(
        apiKey: 'sk-or-test',
        model: 'openai/gpt-4o',
        itemNames: ['Sliced Beef', 'Wide Rice Noodles', 'Stir-fry Sauce'],
      );

      final userMessage = fakeSendUsecase.lastMessages!.last;
      expect(
        userMessage['content'],
        'Sliced Beef, Wide Rice Noodles, Stir-fry Sauce',
      );
    });

    test('throws MealNameGenerationException on an empty response', () async {
      fakeSendUsecase.response = '';

      expect(
        () => usecase.generate(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          itemNames: ['Sliced Beef'],
        ),
        throwsA(isA<MealNameGenerationException>()),
      );
    });

    test('wraps a network/API failure in MealNameGenerationException', () async {
      fakeSendUsecase.error = Exception('network down');

      expect(
        () => usecase.generate(
          apiKey: 'sk-or-test',
          model: 'openai/gpt-4o',
          itemNames: ['Sliced Beef'],
        ),
        throwsA(isA<MealNameGenerationException>()),
      );
    });
  });
}
