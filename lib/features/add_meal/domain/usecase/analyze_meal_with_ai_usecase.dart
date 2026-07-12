import 'dart:convert';

import 'package:opennutritracker/core/data/repository/open_router_repository.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/magic_food_item_entity.dart';

/// Thrown when the AI call itself fails (network, auth, malformed reply).
/// Distinct from a well-formed reply that just found no food, which returns
/// an empty list rather than throwing — the caller decides how to word that.
class MagicAnalysisException implements Exception {
  final String message;
  const MagicAnalysisException(this.message);

  @override
  String toString() => 'MagicAnalysisException: $message';
}

class AnalyzeMealWithAiUsecase {
  final SendOpenRouterChatCompletionUsecase _sendChatCompletionUsecase;

  AnalyzeMealWithAiUsecase(this._sendChatCompletionUsecase);

  Future<List<MagicFoodItemEntity>> analyze({
    required String apiKey,
    required String model,
    required bool mealBreakdown,
    String? description,
    String? base64Image,
    String imageMimeType = 'image/jpeg',
  }) async {
    final userText = (description?.trim().isNotEmpty ?? false)
        ? description!.trim()
        : 'Identify the food and estimate its nutrition.';

    final messages = [
      OpenRouterRepository.textMessage(
        role: 'system',
        text: _systemPrompt(mealBreakdown),
      ),
      base64Image != null
          ? OpenRouterRepository.visionMessage(
              role: 'user',
              text: userText,
              base64Image: base64Image,
              mimeType: imageMimeType,
            )
          : OpenRouterRepository.textMessage(role: 'user', text: userText),
    ];

    String? raw;
    try {
      raw = await _sendChatCompletionUsecase.sendChatCompletion(
        apiKey: apiKey,
        model: model,
        messages: messages,
      );
    } catch (exception) {
      throw MagicAnalysisException(exception.toString());
    }

    if (raw == null || raw.trim().isEmpty) {
      throw const MagicAnalysisException('Empty response from the model');
    }

    return _parseItems(raw);
  }

  String _systemPrompt(bool mealBreakdown) {
    final shapeInstruction = mealBreakdown
        ? 'Identify every distinct food or ingredient you can make out and '
              'return one item per food.'
        : 'Treat the whole plate/description as a single combined item and '
              'return exactly one item summing its total nutrition.';
    return 'You are a nutrition estimation assistant. Analyze the food '
        'described and/or shown in the image and estimate its nutritional '
        'content. $shapeInstruction All numeric values are your best '
        'estimate for the full visible portion, NOT per 100g. Also estimate '
        'the portion weight in grams for that same visible portion, and '
        'rate your own confidence in the estimate as "low", "medium", or '
        '"high". Respond with ONLY a JSON object, no markdown formatting, '
        'no explanation, in exactly this shape: {"items": [{"name": '
        '"string", "kcal": number, "grams": number, "confidence": "low '
        '| medium | high", "carbs_g": number, "fat_g": number, "protein_g": '
        'number}]}. If you cannot identify any food, respond with {"items": '
        '[]}.';
  }

  List<MagicFoodItemEntity> _parseItems(String raw) {
    final jsonString = _stripCodeFences(raw);
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw MagicAnalysisException(
        'Could not parse the model\'s response as JSON: $raw',
      );
    }

    final items = decoded['items'];
    if (items is! List) {
      throw const MagicAnalysisException(
        'Model response was missing an "items" list',
      );
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(_itemFromJson)
        .whereType<MagicFoodItemEntity>()
        .toList();
  }

  MagicFoodItemEntity? _itemFromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final kcal = _asDouble(json['kcal']);
    if (name is! String || name.trim().isEmpty || kcal == null) return null;
    final grams = _asDouble(json['grams']);
    return MagicFoodItemEntity(
      name: name.trim(),
      kcal: kcal,
      // Some models omit or misreport the portion weight — fall back to
      // 100g so the Review meal screen always has a sane rescale basis.
      grams: (grams != null && grams > 0) ? grams : 100,
      confidence: MagicConfidence.fromJson(json['confidence']),
      carbsG: _asDouble(json['carbs_g']),
      fatG: _asDouble(json['fat_g']),
      proteinG: _asDouble(json['protein_g']),
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Some models wrap JSON in ```json ... ``` fences despite instructions
  /// not to — strip those before decoding rather than fail on them.
  String _stripCodeFences(String raw) {
    final trimmed = raw.trim();
    final fenceMatch = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
    ).firstMatch(trimmed);
    return fenceMatch?.group(1) ?? trimmed;
  }
}
