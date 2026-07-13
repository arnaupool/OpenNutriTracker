import 'package:opennutritracker/core/data/repository/body_measurement_repository.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';

class GetBodyMeasurementUsecase {
  final BodyMeasurementRepository _bodyMeasurementRepository;

  GetBodyMeasurementUsecase(this._bodyMeasurementRepository);

  Future<List<BodyMeasurementEntity>> getAllEntries() async {
    return _bodyMeasurementRepository.getAllEntries();
  }

  Future<List<BodyMeasurementEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    return _bodyMeasurementRepository.getEntriesInRange(from, to);
  }
}
