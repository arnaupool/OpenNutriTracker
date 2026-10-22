import 'package:opennutritracker/features/fasting/data/repository/fasting_repository.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';

/// Closes the running session at the moment the user says they ate. The
/// timer never closes a session on its own: reaching the target only
/// changes what the screen shows, so the stored end is always the real one.
/// The framing stays neutral: there is no "broken streak" concept and no
/// "fast ended early" copy; see [FastingSessionEntity.endedAtTime].
class EndFastingUseCase {
  final FastingRepository _repository;

  EndFastingUseCase(this._repository);

  Future<FastingSessionEntity> call(
    FastingSessionEntity session, {
    DateTime? end,
  }) async {
    var at = end ?? DateTime.now();
    // An end before the start would store a negative fast.
    if (at.isBefore(session.startedAt)) at = session.startedAt;
    final updated = session.endedAtTime(at);
    await _repository.updateSession(updated);
    return updated;
  }
}
