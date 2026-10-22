import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/features/fasting/domain/fasting_safety.dart';

/// Persists the user's acknowledgement of the fasting content warning, at
/// the current [FastingSafety.warningVersion]. The dialog stays suppressed
/// until a later version adds information the user has not seen yet.
class AcknowledgeFastingWarningUseCase {
  final ConfigRepository _configRepository;

  AcknowledgeFastingWarningUseCase(this._configRepository);

  Future<void> call() async {
    await _configRepository.setFastingWarningAcknowledged(true);
    await _configRepository.setFastingWarningVersion(
      FastingSafety.warningVersion,
    );
  }
}
