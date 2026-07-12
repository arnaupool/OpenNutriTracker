import 'dart:convert';

import 'package:opennutritracker/core/data/repository/open_router_repository.dart';
import 'package:opennutritracker/core/domain/usecase/send_open_router_chat_completion_usecase.dart';
import 'package:opennutritracker/features/scanner/domain/entity/scanned_label_entity.dart';

/// Thrown when the AI call itself fails (network, auth, malformed reply) or
/// the reply can't be parsed as JSON. A well-formed reply that simply
/// couldn't read a value uses null for that field rather than throwing —
/// the caller (an [EditMealScreen] prefilled from the result) is the
/// review step that catches gaps, not this usecase.
class LabelAnalysisException implements Exception {
  final String message;
  const LabelAnalysisException(this.message);

  @override
  String toString() => 'LabelAnalysisException: $message';
}

/// FR-04: transcribes a photographed nutrition-facts label into a
/// [ScannedLabelEntity]. Deliberately a sibling of [AnalyzeMealWithAiUsecase]
/// rather than a reuse of it — that usecase's prompt asks the model to
/// *estimate* a visible portion of food (with a confidence rating and a
/// "grams eaten" figure); a label instead prints exact per-100g/100ml
/// values that should be *transcribed*, and the fields a label carries
/// (brand, serving size, sodium, saturated fat...) don't overlap cleanly
/// with a plate-of-food model.
class AnalyzeLabelWithAiUsecase {
  final SendOpenRouterChatCompletionUsecase _sendChatCompletionUsecase;

  AnalyzeLabelWithAiUsecase(this._sendChatCompletionUsecase);

  Future<ScannedLabelEntity> analyze({
    required String apiKey,
    required String model,
    required String base64Image,
    String imageMimeType = 'image/jpeg',
  }) async {
    final messages = [
      OpenRouterRepository.textMessage(role: 'system', text: _systemPrompt),
      OpenRouterRepository.visionMessage(
        role: 'user',
        text: 'Read this nutrition label.',
        base64Image: base64Image,
        mimeType: imageMimeType,
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
      throw LabelAnalysisException(exception.toString());
    }

    if (raw == null || raw.trim().isEmpty) {
      throw const LabelAnalysisException('Empty response from the model');
    }

    return _parseLabel(raw);
  }

  static const String _systemPrompt =
      'You are a nutrition-label transcription assistant. Read the '
      'nutrition facts panel and any visible product name/brand in the '
      'image. Prefer the per-100g or per-100ml column when the label '
      'shows one; if only a per-serving value is printed, convert it to '
      'per-100g/100ml using the printed serving size. Respond with ONLY a '
      'JSON object, no markdown formatting, no explanation, in exactly '
      'this shape: {"name": "string or null", "brand": "string or null", '
      '"servingSize": "string or null", "kcal100": number or null, '
      '"carbs100": number or null, "fat100": number or null, '
      '"protein100": number or null, "sugars100": number or null, '
      '"saturatedFat100": number or null, "fiber100": number or null, '
      '"sodiumMg100": number or null}. sodiumMg100 is milligrams per '
      '100g/100ml. Use null for anything you cannot read on the label — '
      'never guess or estimate a value.';

  ScannedLabelEntity _parseLabel(String raw) {
    final jsonString = _stripCodeFences(raw);
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw LabelAnalysisException(
        'Could not parse the model\'s response as JSON: $raw',
      );
    }

    return ScannedLabelEntity(
      name: _asString(decoded['name']),
      brand: _asString(decoded['brand']),
      servingSize: _asString(decoded['servingSize']),
      kcal100: _asDouble(decoded['kcal100']),
      carbs100: _asDouble(decoded['carbs100']),
      fat100: _asDouble(decoded['fat100']),
      protein100: _asDouble(decoded['protein100']),
      sugars100: _asDouble(decoded['sugars100']),
      saturatedFat100: _asDouble(decoded['saturatedFat100']),
      fiber100: _asDouble(decoded['fiber100']),
      sodiumMg100: _asDouble(decoded['sodiumMg100']),
    );
  }

  String? _asString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
