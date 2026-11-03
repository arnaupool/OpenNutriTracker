import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';
import 'package:opennutritracker/features/meal_plan/data/weekly_note_data_source.dart';
import 'package:opennutritracker/features/meal_plan/data/weekly_note_dbo.dart';
import 'package:opennutritracker/features/meal_plan/domain/weekly_note_repository.dart';
import 'package:opennutritracker/features/meal_plan/presentation/weekly_note_card.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/hive_test_setup.dart';

class _Device {
  final Box<WeeklyNoteDBO> box;
  final Box<dynamic> stateBox;
  final SyncEngine engine;

  _Device(this.box, this.stateBox, this.engine);

  static int _n = 0;

  static Future<_Device> create() async {
    final id = _n++;
    final box = await Hive.openBox<WeeklyNoteDBO>('notes$id', bytes: Uint8List(0));
    final stateBox = await Hive.openBox<dynamic>('notestate$id', bytes: Uint8List(0));
    final engine = SyncEngine(
      boxes: [
        SyncedBox<WeeklyNoteDBO>(
          name: 'WeeklyNoteBox',
          box: box,
          identityOf: (_, key) => key?.toString(),
          toJson: (v) => v.toJson(),
          fromJson: WeeklyNoteDBO.fromJson,
          naturalKey: true,
        ),
      ],
    );
    return _Device(box, stateBox, engine);
  }

  WeeklyNoteRepository get repo => WeeklyNoteRepository(WeeklyNoteDataSource(box));

  SyncTarget target(FakeSyncServer server, Uint8List key) =>
      SyncTarget(remote: server.remote('u1'), state: SyncStateStore.account(stateBox, 'u1'), key: key);
}

void main() {
  late Directory dir;

  setUpAll(() {
    registerHiveAdaptersOnce();
    if (!Hive.isAdapterRegistered(WeeklyNoteDBO.hiveTypeId)) {
      Hive.registerAdapter(WeeklyNoteDBOAdapter());
    }
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('notes');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('ISO week key', () {
    test('uses the ISO week and the year of its Thursday', () {
      expect(isoWeekKey(DateTime(2026, 11, 3)), '2026-W45');
      expect(isoWeekKey(DateTime(2026, 11, 2)), '2026-W45'); // Monday
      expect(isoWeekKey(DateTime(2026, 11, 8)), '2026-W45'); // Sunday
      expect(isoWeekKey(DateTime(2021, 1, 3)), '2020-W53');
      expect(isoWeekKey(DateTime(2024, 12, 30)), '2025-W01');
      expect(isoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
    });
  });

  group('checklist lines', () {
    test('only lines starting with - [ ] or - [x] are checkboxes', () {
      final lines = parseNote('Comprar\n- [ ] leche\n- [x] pan\n-[ ] nada\nlibre - [ ] no');
      expect(lines.map((l) => l.isChecklist), [false, true, true, false, false]);
      expect(lines[1].checked, isFalse);
      expect(lines[1].text, 'leche');
      expect(lines[2].checked, isTrue);
    });

    test('toggling flips one box and leaves the rest of the text alone', () {
      const text = 'Comprar\n- [ ] leche\n- [x] pan\nfin';
      expect(toggleChecklistLine(text, 1), 'Comprar\n- [x] leche\n- [x] pan\nfin');
      expect(toggleChecklistLine(text, 2), 'Comprar\n- [ ] leche\n- [ ] pan\nfin');
      expect(toggleChecklistLine(text, 0), text);
      expect(toggleChecklistLine(text, 9), text);
      expect(toggleChecklistLine(toggleChecklistLine(text, 1), 1), text);
    });
  });

  test('the Hive adapter round-trips a note through a closed and reopened box', () async {
    var box = await Hive.openBox<WeeklyNoteDBO>('notes');
    final note = WeeklyNoteDBO(weekKey: '2026-W45', text: 'Hola\n- [ ] leche', modifiedAt: DateTime(2026, 11, 3, 9));
    await box.put(note.weekKey, note);
    await box.close();
    box = await Hive.openBox<WeeklyNoteDBO>('notes');
    expect(box.get('2026-W45')!.toJson(), note.toJson());
    expect(WeeklyNoteDBO.fromJson(jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>).text, note.text);
  });

  test('a blank note is deleted; import keeps the newer copy', () async {
    final repo = WeeklyNoteRepository(WeeklyNoteDataSource(await Hive.openBox<WeeklyNoteDBO>('r')));
    await repo.save('2026-W45', 'algo', now: DateTime(2026, 11, 3));
    expect(repo.textOf('2026-W45'), 'algo');
    await repo.save('2026-W45', '  \n ');
    expect(repo.textOf('2026-W45'), '');

    await repo.save('2026-W45', 'local', now: DateTime(2026, 11, 3));
    final older = WeeklyNoteDBO(weekKey: '2026-W45', text: 'vieja', modifiedAt: DateTime(2026, 11, 1)).toJson();
    final newer = WeeklyNoteDBO(weekKey: '2026-W45', text: 'nueva', modifiedAt: DateTime(2026, 11, 5)).toJson();
    expect(await repo.importJson([older]), 0);
    expect(repo.textOf('2026-W45'), 'local');
    expect(await repo.importJson([newer]), 1);
    expect(repo.textOf('2026-W45'), 'nueva');
    expect(repo.exportJson().single['weekKey'], '2026-W45');
  });

  test('a note syncs between two devices; the last write of the whole note wins', () async {
    final server = FakeSyncServer();
    final key = SyncCrypto.generateKey();
    final phone = await _Device.create();
    final desktop = await _Device.create();
    DateTime at(int m) => DateTime.utc(2026, 11, 3, 12, m);

    await phone.repo.save('2026-W45', 'Lista\n- [ ] leche', now: at(0));
    await phone.engine.sync(phone.target(server, key), now: at(0));
    await desktop.engine.sync(desktop.target(server, key), now: at(1));
    expect(desktop.repo.textOf('2026-W45'), 'Lista\n- [ ] leche');

    await desktop.repo.save('2026-W45', 'Lista\n- [x] leche', now: at(2));
    await desktop.engine.sync(desktop.target(server, key), now: at(2));
    await phone.engine.sync(phone.target(server, key), now: at(3));
    expect(phone.repo.textOf('2026-W45'), 'Lista\n- [x] leche');

    // Clearing the note removes it everywhere.
    await phone.repo.save('2026-W45', '');
    await phone.engine.sync(phone.target(server, key), now: at(4));
    await desktop.engine.sync(desktop.target(server, key), now: at(5));
    expect(desktop.repo.textOf('2026-W45'), '');
  });

  group('WeeklyNoteCard', () {
    Future<WeeklyNoteRepository> pump(WidgetTester tester, {String? text, DateTime? week}) async {
      final repo = WeeklyNoteRepository(
        WeeklyNoteDataSource(await Hive.openBox<WeeklyNoteDBO>('w', bytes: Uint8List(0))),
      );
      if (text != null) await repo.save('2026-W45', text);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyNoteCard(
                week: week ?? DateTime(2026, 11, 3),
                repository: repo,
                saveDelay: const Duration(milliseconds: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('typing saves the note after a pause', (tester) async {
      final repo = await pump(tester);
      // An empty note starts in edit mode.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Menú\n- [ ] comprar');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.textOf('2026-W45'), 'Menú\n- [ ] comprar');
    });

    testWidgets('a saved note shows checkboxes that toggle and autosave', (tester) async {
      final repo = (await tester.runAsync(() => pump(tester, text: 'Menú\n- [ ] comprar\n- [x] cocinar')))!;
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.textOf('2026-W45'), 'Menú\n- [x] comprar\n- [x] cocinar');
    });

    testWidgets('another week shows its own note', (tester) async {
      final repo = await pump(tester, text: 'Esta semana');
      await repo.save('2026-W46', 'La siguiente');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          home: Scaffold(
            body: WeeklyNoteCard(week: DateTime(2026, 11, 10), repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('La siguiente'), findsOneWidget);
      expect(find.text('Esta semana'), findsNothing);
    });
  });
}
