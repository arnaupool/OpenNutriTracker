import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:pointycastle/export.dart';

import '../helpers/fake_sync_server.dart';

void main() {
  const userId = 'user-1';
  late FakeSyncServer server;
  late Uint8List accountKey;

  setUp(() {
    server = FakeSyncServer();
    accountKey = SyncCrypto.generateKey();
  });

  DateTime at(int minute) => DateTime.utc(2026, 10, 22, 12, minute);

  SyncTarget account(FakeSyncDevice device, {Uint8List? key}) =>
      SyncTarget(remote: server.remote(userId), state: device.accountState(userId), key: key ?? accountKey);

  /// The records on the server, without the key-check row.
  List<SyncRow> dataRows() => server.rowsOf(userId).where((r) => r.box != SyncEngine.keyCheckBox).toList();

  group('record sync', () {
    test('the first device uploads everything and another device receives it', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'kcal': 500});
      await phone.diary.add({'id': 'm2', 'kcal': 300});
      await phone.profile.put('UserKey', {'name': 'Arnau'});
      final up = await phone.engine.sync(account(phone), now: at(0));
      expect(up.pushed, 3);

      final desktop = await FakeSyncDevice.create();
      final down = await desktop.engine.sync(account(desktop), now: at(1));
      expect(down.pulled, 3);
      expect(desktop.entries.keys, unorderedEquals(['m1', 'm2']));
      expect(desktop.profile.get('UserKey'), {'name': 'Arnau'});
    });

    test('row ids keep their format, so rows already on a server still match', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(account(phone), now: at(0));
      final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(accountKey));
      final expected = base64Url.encode(mac.process(Uint8List.fromList(utf8.encode('diary\u0000m1'))).sublist(0, 18));
      expect(dataRows().single.id, expected);
    });

    test('payloads on the server are opaque', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'food': 'paella secreta'});
      await phone.engine.sync(account(phone), now: at(0));
      final stored = dataRows().single.payload!;
      expect(stored.contains('paella'), isFalse);
      expect(utf8.decode(base64Decode(stored), allowMalformed: true).contains('paella'), isFalse);
    });

    test('edits and deletions travel both ways', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'kcal': 500});
      await phone.engine.sync(account(phone), now: at(0));
      await desktop.engine.sync(account(desktop), now: at(1));

      await desktop.putEntry('m1', {'kcal': 650});
      await desktop.diary.add({'id': 'm2', 'kcal': 100});
      await desktop.engine.sync(account(desktop), now: at(2));
      await phone.engine.sync(account(phone), now: at(3));
      expect(phone.entries['m1']!['kcal'], 650);
      expect(phone.entries.keys, unorderedEquals(['m1', 'm2']));

      await phone.deleteEntry('m2');
      await phone.engine.sync(account(phone), now: at(4));
      await desktop.engine.sync(account(desktop), now: at(5));
      expect(desktop.entries.keys, ['m1']);
    });

    test('records with clashing int keys on two devices do not overwrite each other', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'phone-meal'});
      await desktop.diary.add({'id': 'desktop-meal'});
      expect(phone.diary.keys.single, desktop.diary.keys.single);

      await phone.engine.sync(account(phone), now: at(0));
      await desktop.engine.sync(account(desktop), now: at(1));
      await phone.engine.sync(account(phone), now: at(2));
      expect(phone.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
      expect(desktop.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
    });

    test('concurrent edits of one record: the later edit wins on both devices', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.profile.put('UserKey', {'weight': 80});
      await phone.engine.sync(account(phone), now: at(0));
      await desktop.engine.sync(account(desktop), now: at(1));

      await phone.profile.put('UserKey', {'weight': 79});
      await desktop.profile.put('UserKey', {'weight': 78});
      await phone.engine.sync(account(phone), now: at(10));
      await desktop.engine.sync(account(desktop), now: at(12));
      await phone.engine.sync(account(phone), now: at(13));
      expect(phone.profile.get('UserKey'), {'weight': 78});
      expect(desktop.profile.get('UserKey'), {'weight': 78});

      // An older write arriving late (an offline device) changes nothing.
      await phone.profile.put('UserKey', {'weight': 90});
      await phone.engine.sync(account(phone), now: at(11));
      await desktop.engine.sync(account(desktop), now: at(14));
      expect(desktop.profile.get('UserKey'), {'weight': 78});
    });

    test('a second sync with no changes moves nothing', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(account(phone), now: at(0));
      final again = await phone.engine.sync(account(phone), now: at(1));
      expect(again.pushed, 0);
      expect(again.pulled, 0);
    });

    test('rows sharing one server time across a page boundary are all pulled', () async {
      final phone = await FakeSyncDevice.create();
      final count = SyncEngine.pageSize + 150;
      for (var i = 0; i < count; i++) {
        await phone.diary.add({'id': 'm$i'});
      }
      // Batches of 200 share one updated_at; page 1 ends inside batch 3.
      await phone.engine.sync(account(phone), now: at(0));
      final desktop = await FakeSyncDevice.create();
      final down = await desktop.engine.sync(account(desktop), now: at(1));
      expect(down.pulled, count);
      expect(desktop.diary.length, count);
    });

    test('a failed push leaves the state alone, so the next sync retries', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      server.failPush = true;
      await expectLater(phone.engine.sync(account(phone), now: at(0)), throwsA(anything));
      expect(phone.accountState(userId).lastSync, isNull);
      server.failPush = false;
      final retry = await phone.engine.sync(account(phone), now: at(1));
      expect(retry.pushed, 1);
    });
  });

  group('accounts', () {
    test('the first device uploads everything, with a key-check row', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'kcal': 500});
      await phone.profile.put('UserKey', {'name': 'Ana'});
      final up = await phone.engine.sync(account(phone), now: at(0));
      expect(up.pushed, 2);
      final rows = server.rowsOf(userId);
      expect(rows.where((r) => r.box == SyncEngine.keyCheckBox), hasLength(1));
      expect(rows, hasLength(3));
      expect(phone.engine.hasLocalChanges(phone.accountState(userId)), isFalse);
    });

    test('signing in elsewhere merges: account copy wins, local-only records go up', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'shared', 'kcal': 500});
      await phone.profile.put('UserKey', {'name': 'Ana', 'weight': 61});
      await phone.engine.sync(account(phone), now: at(0));

      final tablet = await FakeSyncDevice.create();
      await tablet.profile.put('UserKey', {'name': 'onboarding default'});
      await tablet.diary.add({'id': 'shared', 'kcal': 1});
      await tablet.diary.add({'id': 'tablet-only', 'kcal': 200});
      await tablet.engine.sync(account(tablet), now: at(5));
      await phone.engine.sync(account(phone), now: at(6));

      expect(tablet.profile.get('UserKey'), {'name': 'Ana', 'weight': 61});
      expect(tablet.entries['shared']!['kcal'], 500);
      expect(phone.entries.keys, unorderedEquals(['shared', 'tablet-only']));
      expect(phone.profile.get('UserKey'), {'name': 'Ana', 'weight': 61});
    });

    test('after the first sync, edits win by modified_at as before', () async {
      final phone = await FakeSyncDevice.create();
      final tablet = await FakeSyncDevice.create();
      await phone.profile.put('UserKey', {'weight': 61});
      await phone.engine.sync(account(phone), now: at(0));
      await tablet.engine.sync(account(tablet), now: at(1));
      await tablet.profile.put('UserKey', {'weight': 60});
      await tablet.engine.sync(account(tablet), now: at(2));
      await phone.engine.sync(account(phone), now: at(3));
      expect(phone.profile.get('UserKey'), {'weight': 60});
    });

    test('a device holding another data key touches nothing', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(account(phone), now: at(0));
      final before = Map.of(server.rows);

      final stale = await FakeSyncDevice.create();
      await stale.diary.add({'id': 'old-key-entry'});
      await expectLater(
        stale.engine.sync(account(stale, key: SyncCrypto.generateKey()), now: at(1)),
        throwsA(isA<SyncKeyMismatchException>()),
      );
      expect(server.rows.keys, before.keys);
      expect(stale.entries.keys, ['old-key-entry']);
    });

    test('hasLocalChanges sees additions, edits and deletions', () async {
      final phone = await FakeSyncDevice.create();
      final state = phone.accountState(userId);
      expect(phone.engine.hasLocalChanges(state), isFalse);
      await phone.diary.add({'id': 'm1'});
      expect(phone.engine.hasLocalChanges(state), isTrue);
      await phone.engine.sync(account(phone), now: at(0));
      expect(phone.engine.hasLocalChanges(state), isFalse);
      await phone.putEntry('m1', {'kcal': 1});
      expect(phone.engine.hasLocalChanges(state), isTrue);
      await phone.engine.sync(account(phone), now: at(1));
      await phone.deleteEntry('m1');
      expect(phone.engine.hasLocalChanges(state), isTrue);
      await phone.engine.sync(account(phone), now: at(2));
      expect(phone.engine.hasLocalChanges(state), isFalse);
    });
  });
}
