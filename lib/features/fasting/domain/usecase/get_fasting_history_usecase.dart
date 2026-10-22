import 'package:opennutritracker/features/fasting/data/repository/fasting_repository.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';

/// Closed sessions, newest first.
class GetFastingHistoryUseCase {
  final FastingRepository _repository;

  GetFastingHistoryUseCase(this._repository);

  Future<List<FastingSessionEntity>> call() async {
    final all = await _repository.allSessions();
    final closed = all.where((s) => !s.isActive).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return closed;
  }
}
