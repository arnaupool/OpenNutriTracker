import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';

/// In-memory stand-in for `public.sync_records`: the same rules as the SQL
/// (server clock on every write, older `modified_at` ignored, rows scoped by
/// token).
class _FakeServer implements SyncRemote {
  final Map<String, SyncRow> rows = {};
  var _tick = DateTime.utc(2026, 1, 1);

  @override
  Future<List<SyncRow>> pull(String token, DateTime? since, {int limit = 500}) async {
    final matching = rows.entries
        .where((e) => e.key.startsWith('$token|'))
        .map((e) => e.value)
        .where((r) => since == null || r.updatedAt!.isAfter(since))
        .toList()
      ..sort((a, b) => a.updatedAt!.compareTo(b.updatedAt!));
    return matching.take(limit).toList();
  }

  @override
  Future<void> push(String token, List<SyncRow> batch) async {
    for (final r in batch) {
      final key = '$token|${r.box}|${r.id}';
      final existing = rows[key];
      if (existing != null && r.modifiedAt.isBefore(existing.modifiedAt)) continue;
      _tick = _tick.add(const Duration(seconds: 1));
      rows[key] = SyncRow(
        box: r.box,
        id: r.id,
        payload: r.payload,
        modifiedAt: r.modifiedAt,
        updatedAt: _tick,
        deleted: r.deleted,
      );
    }
  }
}

/// One simulated device: a "diary" box with auto-increment keys (records
/// matched by their own id) and a "profile" box keyed by a fixed key.
class _Device {
  final Box<Map> diary;
  final Box<Map> profile;
  final SyncStateStore state;
  final SyncEngine engine;

  _Device(this.diary, this.profile, this.state, this.engine);

  static int _n = 0;

  static Future<_Device> create(SyncRemote remote) async {
    final id = _n++;
    final diary = await Hive.openBox<Map>('diary$id', bytes: Uint8List(0));
    final profile = await Hive.openBox<Map>('profile$id', bytes: Uint8List(0));
    final state = SyncStateStore(await Hive.openBox<dynamic>('state$id', bytes: Uint8List(0)));
    final engine = SyncEngine(
      boxes: [
        SyncedBox<Map>(
          name: 'diary',
          box: diary,
          identityOf: (v, _) => v['id'] as String?,
          toJson: (v) => Map<String, dynamic>.from(v),
          fromJson: (j) => j,
        ),
        SyncedBox<Map>(
          name: 'profile',
          box: profile,
          identityOf: (_, k) => k?.toString(),
          toJson: (v) => Map<String, dynamic>.from(v),
          fromJson: (j) => j,
          naturalKey: true,
        ),
      ],
      remote: remote,
      state: state,
    );
    return _Device(diary, profile, state, engine);
  }

  Map<String, Map> get entries => {for (final v in diary.values) v['id'] as String: v};
}

void main() {
  late _FakeServer server;
  late SyncPairing pairing;

  setUp(() {
    server = _FakeServer();
    pairing = SyncPairing('a' * 64, SyncCrypto.generateKey());
  });

  DateTime at(int minute) => DateTime.utc(2026, 10, 22, 12, minute);

  test('the owner uploads everything and a linked device receives it', () async {
    final phone = await _Device.create(server);
    await phone.diary.add({'id': 'm1', 'kcal': 500});
    await phone.diary.add({'id': 'm2', 'kcal': 300});
    await phone.profile.put('UserKey', {'name': 'Arnau'});
    final up = await phone.engine.sync(pairing, now: at(0));
    expect(up.pushed, 3);

    final desktop = await _Device.create(server);
    await desktop.state.setJoining(true);
    final down = await desktop.engine.sync(pairing, now: at(1));
    expect(down.pulled, 3);
    expect(desktop.entries.keys, unorderedEquals(['m1', 'm2']));
    expect(desktop.profile.get('UserKey'), {'name': 'Arnau'});
  });

  test('payloads on the server are opaque', () async {
    final phone = await _Device.create(server);
    await phone.diary.add({'id': 'm1', 'food': 'paella secreta'});
    await phone.engine.sync(pairing, now: at(0));
    final stored = server.rows.values.single.payload!;
    expect(stored.contains('paella'), isFalse);
    expect(utf8.decode(base64Decode(stored), allowMalformed: true).contains('paella'), isFalse);
  });

  test('edits and deletions travel both ways', () async {
    final phone = await _Device.create(server);
    final desktop = await _Device.create(server);
    await phone.diary.add({'id': 'm1', 'kcal': 500});
    await phone.engine.sync(pairing, now: at(0));
    await desktop.engine.sync(pairing, now: at(1));

    final key = desktop.diary.keys.single;
    await desktop.diary.put(key, {'id': 'm1', 'kcal': 650});
    await desktop.diary.add({'id': 'm2', 'kcal': 100});
    await desktop.engine.sync(pairing, now: at(2));
    await phone.engine.sync(pairing, now: at(3));
    expect(phone.entries['m1']!['kcal'], 650);
    expect(phone.entries.keys, unorderedEquals(['m1', 'm2']));

    final m2Key = phone.diary.keys.firstWhere((k) => phone.diary.get(k)!['id'] == 'm2');
    await phone.diary.delete(m2Key);
    await phone.engine.sync(pairing, now: at(4));
    await desktop.engine.sync(pairing, now: at(5));
    expect(desktop.entries.keys, ['m1']);
  });

  test('records with clashing int keys on two devices do not overwrite each other', () async {
    final phone = await _Device.create(server);
    final desktop = await _Device.create(server);
    await phone.diary.add({'id': 'phone-meal'});
    await desktop.diary.add({'id': 'desktop-meal'});
    expect(phone.diary.keys.single, desktop.diary.keys.single);

    await phone.engine.sync(pairing, now: at(0));
    await desktop.engine.sync(pairing, now: at(1));
    await phone.engine.sync(pairing, now: at(2));
    expect(phone.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
    expect(desktop.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
  });

  test('concurrent edits of one record: the later edit wins on both devices', () async {
    final phone = await _Device.create(server);
    final desktop = await _Device.create(server);
    await phone.profile.put('UserKey', {'weight': 80});
    await phone.engine.sync(pairing, now: at(0));
    await desktop.engine.sync(pairing, now: at(1));

    await phone.profile.put('UserKey', {'weight': 79});
    await desktop.profile.put('UserKey', {'weight': 78});
    await phone.engine.sync(pairing, now: at(10));
    await desktop.engine.sync(pairing, now: at(12));
    await phone.engine.sync(pairing, now: at(13));
    expect(phone.profile.get('UserKey'), {'weight': 78});
    expect(desktop.profile.get('UserKey'), {'weight': 78});

    // An older write arriving late (an offline device) changes nothing.
    await phone.profile.put('UserKey', {'weight': 90});
    await phone.engine.sync(pairing, now: at(11));
    await desktop.engine.sync(pairing, now: at(14));
    expect(desktop.profile.get('UserKey'), {'weight': 78});
  });

  test('a newly linked device does not overwrite real data with its own defaults', () async {
    final phone = await _Device.create(server);
    await phone.profile.put('UserKey', {'name': 'Arnau', 'weight': 80});
    await phone.engine.sync(pairing, now: at(0));

    final desktop = await _Device.create(server);
    await desktop.profile.put('UserKey', {'name': 'onboarding default'});
    await desktop.diary.add({'id': 'only-on-desktop'});
    await desktop.state.setJoining(true);
    await desktop.engine.sync(pairing, now: at(5));
    await phone.engine.sync(pairing, now: at(6));

    expect(desktop.profile.get('UserKey'), {'name': 'Arnau', 'weight': 80});
    expect(phone.profile.get('UserKey'), {'name': 'Arnau', 'weight': 80});
    expect(phone.entries.keys, ['only-on-desktop']);
    expect(desktop.state.joining, isFalse);
  });

  test('a second sync with no changes moves nothing', () async {
    final phone = await _Device.create(server);
    await phone.diary.add({'id': 'm1'});
    await phone.engine.sync(pairing, now: at(0));
    final again = await phone.engine.sync(pairing, now: at(1));
    expect(again.pushed, 0);
    expect(again.pulled, 0);
  });

  test('rows encrypted with another key are skipped, not applied', () async {
    final phone = await _Device.create(server);
    await phone.diary.add({'id': 'm1'});
    await phone.engine.sync(pairing, now: at(0));

    final intruder = await _Device.create(server);
    final result = await intruder.engine.sync(SyncPairing(pairing.token, SyncCrypto.generateKey()), now: at(1));
    // With another key even the hashed box names don't match, so the rows
    // are ignored outright.
    expect(result.pulled, 0);
    expect(intruder.diary.isEmpty, isTrue);
  });

  group('pairing code', () {
    test('round-trips token and key', () {
      final code = pairing.encode();
      final parsed = SyncPairing.tryParse(code)!;
      expect(parsed.token, pairing.token);
      expect(parsed.key, pairing.key);
    });

    test('rejects bare backup tokens and garbage', () {
      expect(SyncPairing.tryParse('a' * 64), isNull);
      expect(SyncPairing.tryParse('ontsync1:nothex.AAAA'), isNull);
      expect(SyncPairing.tryParse('ontsync1:${'a' * 64}.AAAA'), isNull);
    });
  });
}
