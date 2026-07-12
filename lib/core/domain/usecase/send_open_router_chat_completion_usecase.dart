import 'package:opennutritracker/core/data/repository/open_router_repository.dart';

class SendOpenRouterChatCompletionUsecase {
  final OpenRouterRepository _openRouterRepository;

  SendOpenRouterChatCompletionUsecase(this._openRouterRepository);

  Future<String?> sendChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    return await _openRouterRepository.sendChatCompletion(
      apiKey: apiKey,
      model: model,
      messages: messages,
    );
  }
}
