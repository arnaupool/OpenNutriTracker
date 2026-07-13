import 'package:opennutritracker/core/data/repository/body_measurement_repository.dart';

class DeleteBodyMeasurementUsecase {
  final BodyMeasurementRepository _bodyMeasurementRepository;

  DeleteBodyMeasurementUsecase(this._bodyMeasurementRepository);

  Future<void> deleteEntry(DateTime date) async {
    await _bodyMeasurementRepository.deleteEntry(date);
  }
}
