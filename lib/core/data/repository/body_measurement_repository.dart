import 'package:opennutritracker/core/data/data_source/body_measurement_data_source.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';

class BodyMeasurementRepository {
  final BodyMeasurementDataSource _bodyMeasurementDataSource;

  BodyMeasurementRepository(this._bodyMeasurementDataSource);

  Future<void> addEntry(BodyMeasurementEntity entry) async {
    await _bodyMeasurementDataSource.addEntry(
      BodyMeasurementDBO.fromBodyMeasurementEntity(entry),
    );
  }

  Future<List<BodyMeasurementEntity>> getAllEntries() async {
    final dbos = await _bodyMeasurementDataSource.allEntries();
    return dbos.map(BodyMeasurementEntity.fromBodyMeasurementDBO).toList();
  }

  Future<List<BodyMeasurementEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    final dbos = await _bodyMeasurementDataSource.entriesInRange(from, to);
    return dbos.map(BodyMeasurementEntity.fromBodyMeasurementDBO).toList();
  }

  Future<BodyMeasurementEntity?> getEntry(DateTime date) async {
    final dbo = await _bodyMeasurementDataSource.getEntry(date);
    return dbo == null
        ? null
        : BodyMeasurementEntity.fromBodyMeasurementDBO(dbo);
  }

  Future<void> deleteEntry(DateTime date) async {
    await _bodyMeasurementDataSource.deleteEntry(date);
  }
}
