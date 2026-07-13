import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/body_measurement_data_source.dart';
import 'package:opennutritracker/core/data/dbo/body_measurement_dbo.dart';

import '../helpers/hive_test_setup.dart';

void main() {
  group('BodyMeasurementDataSource', () {
    late Box<BodyMeasurementDBO> box;
    late BodyMeasurementDataSource dataSource;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      Hive.init('.');
      box = await Hive.openBox<BodyMeasurementDBO>(
        'body_measurement_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      dataSource = BodyMeasurementDataSource(box);
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('write then read returns the same entry', () async {
      final day = DateTime.utc(2025, 3, 12);

      await dataSource.addEntry(
        BodyMeasurementDBO(
          date: day,
          waistCm: 82.0,
          hipsCm: 98.5,
          note: 'morning',
        ),
      );

      final entry = await dataSource.getEntry(day);
      expect(entry, isNotNull);
      expect(entry!.waistCm, equals(82.0));
      expect(entry.hipsCm, equals(98.5));
      expect(entry.note, equals('morning'));
    });

    test('unset metrics stay null so partial entries are supported',
        () async {
      final day = DateTime.utc(2025, 3, 12);

      await dataSource.addEntry(BodyMeasurementDBO(date: day, waistCm: 82.0));

      final entry = await dataSource.getEntry(day);
      expect(entry!.waistCm, equals(82.0));
      expect(entry.neckCm, isNull);
      expect(entry.chestCm, isNull);
      expect(entry.hipsCm, isNull);
    });

    test('saving twice for the same day overwrites the previous reading',
        () async {
      final day = DateTime.utc(2025, 3, 12);

      await dataSource.addEntry(BodyMeasurementDBO(date: day, waistCm: 82.0));
      await dataSource.addEntry(BodyMeasurementDBO(date: day, waistCm: 81.5));

      final all = await dataSource.allEntries();
      expect(all.length, equals(1));
      expect(all.first.waistCm, equals(81.5));
    });

    test('entriesInRange returns only entries inside the bounds, inclusive',
        () async {
      await dataSource.addEntry(
        BodyMeasurementDBO(date: DateTime.utc(2025, 3, 10), waistCm: 83.0),
      );
      await dataSource.addEntry(
        BodyMeasurementDBO(date: DateTime.utc(2025, 3, 12), waistCm: 82.0),
      );
      await dataSource.addEntry(
        BodyMeasurementDBO(date: DateTime.utc(2025, 3, 20), waistCm: 81.0),
      );

      final result = await dataSource.entriesInRange(
        DateTime.utc(2025, 3, 10),
        DateTime.utc(2025, 3, 12),
      );

      expect(result.length, equals(2));
      final dates = result.map((e) => e.date).toList();
      expect(
        dates,
        containsAll([DateTime.utc(2025, 3, 10), DateTime.utc(2025, 3, 12)]),
      );
    });

    test('deleteEntry removes the entry for that day only', () async {
      final keep = DateTime.utc(2025, 3, 10);
      final drop = DateTime.utc(2025, 3, 12);

      await dataSource.addEntry(BodyMeasurementDBO(date: keep, waistCm: 83.0));
      await dataSource.addEntry(BodyMeasurementDBO(date: drop, waistCm: 82.0));

      await dataSource.deleteEntry(drop);

      final all = await dataSource.allEntries();
      expect(all.length, equals(1));
      expect(all.first.date, equals(keep));
    });

    test('allEntries returns every saved entry', () async {
      await dataSource.addEntry(
        BodyMeasurementDBO(date: DateTime.utc(2025, 1, 1), waistCm: 84.0),
      );
      await dataSource.addEntry(
        BodyMeasurementDBO(date: DateTime.utc(2025, 2, 1), waistCm: 83.0),
      );

      final all = await dataSource.allEntries();
      expect(all.length, equals(2));
    });
  });
}
