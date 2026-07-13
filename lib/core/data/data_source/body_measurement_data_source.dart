import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';
import 'package:opennutritracker/core/utils/extensions.dart';

class BodyMeasurementDataSource {
  final log = Logger('BodyMeasurementDataSource');
  final Box<BodyMeasurementDBO> _bodyMeasurementBox;

  BodyMeasurementDataSource(this._bodyMeasurementBox);

  /// Stores a single entry keyed by its day (`yyyy-MM-dd`), mirroring
  /// WeightLogDataSource — a second entry for the same calendar day
  /// overwrites the first rather than appending, since measurements are
  /// a periodic (weekly/monthly) reading, not a running log.
  Future<void> addEntry(BodyMeasurementDBO entry) async {
    log.fine('Adding body measurement entry for ${entry.date}');
    await _bodyMeasurementBox.put(entry.date.toParsedDay(), entry);
  }

  Future<List<BodyMeasurementDBO>> allEntries() async {
    return _bodyMeasurementBox.values.toList();
  }

  Future<List<BodyMeasurementDBO>> entriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    return _bodyMeasurementBox.values
        .where(
          (entry) => !entry.date.isBefore(from) && !entry.date.isAfter(to),
        )
        .toList();
  }

  Future<BodyMeasurementDBO?> getEntry(DateTime date) async {
    return _bodyMeasurementBox.get(date.toParsedDay());
  }

  Future<void> deleteEntry(DateTime date) async {
    log.fine('Deleting body measurement entry for $date');
    await _bodyMeasurementBox.delete(date.toParsedDay());
  }
}
