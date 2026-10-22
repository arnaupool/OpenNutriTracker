import 'package:opennutritracker/features/fasting/data/repository/fasting_repository.dart';
import 'package:opennutritracker/features/fasting/domain/entity/fasting_session_entity.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';

/// Adds or edits a session (a past fast typed in by hand, a corrected start
/// time on the running one) after checking it against the clock and the
/// rest of the history. Returns the reason it was rejected, or null when it
/// was stored.
class SaveFastingSessionUseCase {
  final FastingRepository _repository;

  SaveFastingSessionUseCase(this._repository);

  Future<FastingWindowError?> call(
    FastingSessionEntity session, {
    DateTime? now,
  }) async {
    final others = await _repository.allSessions();
    final error = FastingSafety.validateWindow(
      start: session.startedAt,
      end: session.endedAt,
      now: now ?? DateTime.now(),
      others: others,
      ignoreId: session.id,
    );
    if (error != null) return error;
    await _repository.updateSession(session);
    return null;
  }
}
