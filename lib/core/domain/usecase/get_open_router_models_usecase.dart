import 'package:opennutritracker/core/data/repository/open_router_repository.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';

class GetOpenRouterModelsUsecase {
  final OpenRouterRepository _openRouterRepository;

  GetOpenRouterModelsUsecase(this._openRouterRepository);

  Future<List<OpenRouterModelEntity>> getModels() async {
    return await _openRouterRepository.getAvailableModels();
  }
}
