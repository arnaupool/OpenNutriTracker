import 'package:opennutritracker/features/fasting/data/repository/fasting_repository.dart';

class DeleteFastingSessionUseCase {
  final FastingRepository _repository;

  DeleteFastingSessionUseCase(this._repository);

  Future<void> call(String id) => _repository.deleteSession(id);
}
