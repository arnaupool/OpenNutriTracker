import 'package:opennutritracker/core/data/repository/body_measurement_repository.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';

class AddBodyMeasurementUsecase {
  final BodyMeasurementRepository _bodyMeasurementRepository;

  AddBodyMeasurementUsecase(this._bodyMeasurementRepository);

  Future<void> addEntry(BodyMeasurementEntity entry) async {
    await _bodyMeasurementRepository.addEntry(entry);
  }
}
