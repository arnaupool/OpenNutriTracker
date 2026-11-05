import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/sync/sync_boxes.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';

import '../helpers/fake_sync_server.dart';
import '../helpers/hive_test_setup.dart';

class _Device {
  final Box<ConfigDBO> box;
  final Box<dynamic> stateBox;
  final SyncEngine engine;

  _Device(this.box, this.stateBox, this.engine);

  static int _n = 0;

  static Future<_Device> create() async {
    final id = _n++;
    final box = await Hive.openBox<ConfigDBO>('config$id', bytes: Uint8List(0));
    final stateBox = await Hive.openBox<dynamic>('configstate$id', bytes: Uint8List(0));
    return _Device(box, stateBox, SyncEngine(boxes: [configSyncedBox(box)]));
  }

  SyncTarget target(FakeSyncServer server, Uint8List key) =>
      SyncTarget(remote: server.remote('u1'), state: SyncStateStore.account(stateBox, 'u1'), key: key);
}

void main() {
  late Directory dir;

  setUpAll(registerHiveAdaptersOnce);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('configsync');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('settings sync between devices but each keeps its own language', () async {
    final server = FakeSyncServer();
    final key = SyncCrypto.generateKey();
    final phone = await _Device.create();
    final desktop = await _Device.create();
    DateTime at(int m) => DateTime.utc(2026, 11, 5, 12, m);

    await phone.box.put('ConfigKey', ConfigDBO.empty()..selectedLocale = 'es');
    await desktop.box.put('ConfigKey', ConfigDBO.empty()..selectedLocale = 'en');

    await phone.engine.sync(phone.target(server, key), now: at(0));
    await desktop.engine.sync(desktop.target(server, key), now: at(1));
    expect(desktop.box.get('ConfigKey')!.selectedLocale, 'en');
    // The desktop changes a shared setting, so its copy is the newest.
    desktop.box.get('ConfigKey')!.usesImperialUnits = true;
    await desktop.box.get('ConfigKey')!.save();
    await desktop.engine.sync(desktop.target(server, key), now: at(2));
    await phone.engine.sync(phone.target(server, key), now: at(3));

    expect(phone.box.get('ConfigKey')!.usesImperialUnits, isTrue);
    expect(phone.box.get('ConfigKey')!.selectedLocale, 'es');
    expect(desktop.box.get('ConfigKey')!.selectedLocale, 'en');
  });
}
