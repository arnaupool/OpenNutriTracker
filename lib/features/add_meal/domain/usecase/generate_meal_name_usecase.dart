import 'package:opennutritracker/core/data/repository/open_router_repository.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';

/// Thrown when the AI call itself fails (network, auth). Naming is a
/// nice-to-have suggestion, not a blocking step — callers should catch this
/// and fall back to an empty/manual name rather than surfacing an error.
class MealNameGenerationException implements Exception {
  final String message;
  const MealNameGenerationException(this.message);

  @override
  String toString() => 'MealNameGenerationException: $message';
}

/// FR-05: suggests a short, natural name for a multi-item meal breakdown so
/// the "Save as preset" dialog doesn't hand the user a blank field — e.g.
/// "Sliced Beef, Wide Rice Noodles, Stir-fry Sauce" → "Beef Noodle
/// Stir-Fry". The suggestion is always editable before saving; this never
/// writes anything on its own.
class GenerateMealNameUsecase {
  final SendOpenRouterChatCompletionUsecase _sendChatCompletionUsecase;

  GenerateMealNameUsecase(this._sendChatCompletionUsecase);

  Future<String> generate({
    required String apiKey,
    required String model,
    required List<String> itemNames,
  }) async {
    if (itemNames.isEmpty) return '';

    final messages = [
      OpenRouterRepository.textMessage(role: 'system', text: _systemPrompt),
      OpenRouterRepository.textMessage(
        role: 'user',
        text: itemNames.join(', '),
      ),
    ];

    String? raw;
    try {
      raw = await _sendChatCompletionUsecase.sendChatCompletion(
        apiKey: apiKey,
        model: model,
        messages: messages,
      );
    } catch (exception) {
      throw MealNameGenerationException(exception.toString());
    }

    if (raw == null || raw.trim().isEmpty) {
      throw const MealNameGenerationException('Empty response from the model');
    }

    return _clean(raw);
  }

  static const String _systemPrompt =
      'You suggest short, natural names for a home-cooked meal or snack '
      'given a list of its components, so a person can save it as a '
      'reusable preset in a food-tracking app. Respond with ONLY the '
      'name itself — 2 to 5 words, title case, no quotation marks, no '
      'trailing punctuation, no explanation.';

  /// Models sometimes wrap the name in quotes or add a trailing period
  /// despite instructions not to — strip those rather than fail on them.
  String _clean(String raw) {
    var cleaned = raw.trim();
    if (cleaned.length >= 2 &&
        cleaned.startsWith('"') &&
        cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned;
  }
}
