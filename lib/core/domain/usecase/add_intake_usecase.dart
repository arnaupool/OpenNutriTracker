import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

class AddIntakeUsecase {
  final IntakeRepository _intakeRepository;

  /// Called after an intake is stored (the reminders use it to flag the meal
  /// as logged). Must not throw; failures are its own business.
  final Future<void> Function(IntakeEntity intake)? onIntakeAdded;

  AddIntakeUsecase(this._intakeRepository, {this.onIntakeAdded});

  Future<void> addIntake(IntakeEntity intakeEntity) async {
    await _intakeRepository.addIntake(intakeEntity);
    final callback = onIntakeAdded;
    if (callback != null) {
      // Fire and forget: logging a meal never waits on the network.
      callback(intakeEntity).catchError((Object _) {});
    }
  }
}
