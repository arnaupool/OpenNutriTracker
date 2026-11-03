import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:pointycastle/export.dart';

import '../helpers/fake_sync_server.dart';

void main() {
  late FakeSyncServer server;
  late SyncPairing pairing;

  setUp(() {
    server = FakeSyncServer();
    pairing = SyncPairing('a' * 64, SyncCrypto.generateKey());
  });

  DateTime at(int minute) => DateTime.utc(2026, 10, 22, 12, minute);

  /// The old pairing-token set of [device].
  SyncTarget token(FakeSyncDevice device, [SyncPairing? other]) {
    final p = other ?? pairing;
    return SyncTarget(remote: server.remote(p.token), state: device.tokenState, key: p.key);
  }

  group('token sets', () {
    test('the owner uploads everything and a linked device receives it', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'kcal': 500});
      await phone.diary.add({'id': 'm2', 'kcal': 300});
      await phone.profile.put('UserKey', {'name': 'Arnau'});
      final up = await phone.engine.sync(token(phone), now: at(0));
      expect(up.pushed, 3);

      final desktop = await FakeSyncDevice.create();
      await desktop.tokenState.setJoining(true);
      final down = await desktop.engine.sync(token(desktop), now: at(1));
      expect(down.pulled, 3);
      expect(desktop.entries.keys, unorderedEquals(['m1', 'm2']));
      expect(desktop.profile.get('UserKey'), {'name': 'Arnau'});
    });

    test('row ids keep their format, so rows already on a server still match', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(token(phone), now: at(0));
      final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(pairing.key));
      final expected = base64Url.encode(mac.process(Uint8List.fromList(utf8.encode('diary\u0000m1'))).sublist(0, 18));
      expect(server.rows.values.single.id, expected);
    });

    test('payloads on the server are opaque', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'food': 'paella secreta'});
      await phone.engine.sync(token(phone), now: at(0));
      final stored = server.rows.values.single.payload!;
      expect(stored.contains('paella'), isFalse);
      expect(utf8.decode(base64Decode(stored), allowMalformed: true).contains('paella'), isFalse);
    });

    test('edits and deletions travel both ways', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1', 'kcal': 500});
      await phone.engine.sync(token(phone), now: at(0));
      await desktop.engine.sync(token(desktop), now: at(1));

      await desktop.putEntry('m1', {'kcal': 650});
      await desktop.diary.add({'id': 'm2', 'kcal': 100});
      await desktop.engine.sync(token(desktop), now: at(2));
      await phone.engine.sync(token(phone), now: at(3));
      expect(phone.entries['m1']!['kcal'], 650);
      expect(phone.entries.keys, unorderedEquals(['m1', 'm2']));

      await phone.deleteEntry('m2');
      await phone.engine.sync(token(phone), now: at(4));
      await desktop.engine.sync(token(desktop), now: at(5));
      expect(desktop.entries.keys, ['m1']);
    });

    test('records with clashing int keys on two devices do not overwrite each other', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'phone-meal'});
      await desktop.diary.add({'id': 'desktop-meal'});
      expect(phone.diary.keys.single, desktop.diary.keys.single);

      await phone.engine.sync(token(phone), now: at(0));
      await desktop.engine.sync(token(desktop), now: at(1));
      await phone.engine.sync(token(phone), now: at(2));
      expect(phone.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
      expect(desktop.entries.keys, unorderedEquals(['phone-meal', 'desktop-meal']));
    });

    test('concurrent edits of one record: the later edit wins on both devices', () async {
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.profile.put('UserKey', {'weight': 80});
      await phone.engine.sync(token(phone), now: at(0));
      await desktop.engine.sync(token(desktop), now: at(1));

      await phone.profile.put('UserKey', {'weight': 79});
      await desktop.profile.put('UserKey', {'weight': 78});
      await phone.engine.sync(token(phone), now: at(10));
      await desktop.engine.sync(token(desktop), now: at(12));
      await phone.engine.sync(token(phone), now: at(13));
      expect(phone.profile.get('UserKey'), {'weight': 78});
      expect(desktop.profile.get('UserKey'), {'weight': 78});

      // An older write arriving late (an offline device) changes nothing.
      await phone.profile.put('UserKey', {'weight': 90});
      await phone.engine.sync(token(phone), now: at(11));
      await desktop.engine.sync(token(desktop), now: at(14));
      expect(desktop.profile.get('UserKey'), {'weight': 78});
    });

    test('a newly linked device does not overwrite real data with its own defaults', () async {
      final phone = await FakeSyncDevice.create();
      await phone.profile.put('UserKey', {'name': 'Arnau', 'weight': 80});
      await phone.engine.sync(token(phone), now: at(0));

      final desktop = await FakeSyncDevice.create();
      await desktop.profile.put('UserKey', {'name': 'onboarding default'});
      await desktop.diary.add({'id': 'only-on-desktop'});
      await desktop.tokenState.setJoining(true);
      await desktop.engine.sync(token(desktop), now: at(5));
      await phone.engine.sync(token(phone), now: at(6));

      expect(desktop.profile.get('UserKey'), {'name': 'Arnau', 'weight': 80});
      expect(phone.profile.get('UserKey'), {'name': 'Arnau', 'weight': 80});
      expect(phone.entries.keys, ['only-on-desktop']);
      expect(desktop.tokenState.joining, isFalse);
    });

    test('a second sync with no changes moves nothing', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(token(phone), now: at(0));
      final again = await phone.engine.sync(token(phone), now: at(1));
      expect(again.pushed, 0);
      expect(again.pulled, 0);
    });

    test('rows encrypted with another key are skipped, not applied', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(token(phone), now: at(0));

      final intruder = await FakeSyncDevice.create();
      final result = await intruder.engine.sync(
        token(intruder, SyncPairing(pairing.token, SyncCrypto.generateKey())),
        now: at(1),
      );
      // With another key even the hashed box names don't match, so the rows
      // are ignored outright.
      expect(result.pulled, 0);
      expect(intruder.diary.isEmpty, isTrue);
    });

    test('rows sharing one server time across a page boundary are all pulled', () async {
      final phone = await FakeSyncDevice.create();
      final count = SyncEngine.pageSize + 150;
      for (var i = 0; i < count; i++) {
        await phone.diary.add({'id': 'm$i'});
      }
      // Batches of 200 share one updated_at; page 1 ends inside batch 3.
      await phone.engine.sync(token(phone), now: at(0));
      final desktop = await FakeSyncDevice.create();
      final down = await desktop.engine.sync(token(desktop), now: at(1));
      expect(down.pulled, count);
      expect(desktop.diary.length, count);
    });

    test('a failed push leaves the state alone, so the next sync retries', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      server.failPush = true;
      await expectLater(phone.engine.sync(token(phone), now: at(0)), throwsA(anything));
      expect(phone.tokenState.lastSync, isNull);
      server.failPush = false;
      final retry = await phone.engine.sync(token(phone), now: at(1));
      expect(retry.pushed, 1);
    });
  });

  group('accounts', () {
    const userId = 'user-1';
    late Uint8List accountKey;

    setUp(() => accountKey = SyncCrypto.generateKey());

    SyncTarget account(FakeSyncDevice device, {Uint8List? key, SyncSeed? seed}) => SyncTarget(
      remote: server.remote(userId),
      state: device.accountState(userId),
      key: key ?? accountKey,
      account: true,
      seed: seed,
    );

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

    test('migration from a token set keeps whichever copy really changed last', () async {
      // Phone and desktop share a token set.
      final phone = await FakeSyncDevice.create();
      final desktop = await FakeSyncDevice.create();
      await phone.profile.put('UserKey', {'weight': 80});
      await phone.diary.add({'id': 'breakfast', 'kcal': 300});
      await phone.diary.add({'id': 'gone', 'kcal': 1});
      await phone.engine.sync(token(phone), now: at(0));
      await desktop.engine.sync(token(desktop), now: at(1));

      // The phone migrates first (its seed is the token set as of now).
      await phone.engine.sync(token(phone), now: at(10));
      final phoneSeed = await phone.engine.readSeed(server.remote(pairing.token), pairing.key, phone.tokenState);
      await phone.engine.sync(account(phone, seed: phoneSeed), now: at(10));
      // ...and edits through the account afterwards.
      await phone.diary.add({'id': 'lunch', 'kcal': 700});
      await phone.putEntry('breakfast', {'kcal': 350});
      await phone.engine.sync(account(phone), now: at(20));

      // Meanwhile the desktop, still on the token set, edits the weight
      // (later than the phone's account copy) and deletes an entry.
      await desktop.profile.put('UserKey', {'weight': 79});
      await desktop.deleteEntry('gone');
      await desktop.engine.sync(token(desktop), now: at(30));

      // Then it signs in: token sync, seed, first account sync.
      await desktop.engine.sync(token(desktop), now: at(40));
      final seed = await desktop.engine.readSeed(server.remote(pairing.token), pairing.key, desktop.tokenState);
      await desktop.engine.sync(account(desktop, seed: seed), now: at(40));
      await phone.engine.sync(account(phone), now: at(41));

      for (final device in [phone, desktop]) {
        expect(device.profile.get('UserKey'), {'weight': 79}, reason: 'desktop edit is newer');
        expect(device.entries['breakfast']!['kcal'], 350, reason: 'phone edit is newer than the stale copy');
        expect(device.entries.keys, unorderedEquals(['breakfast', 'lunch']));
      }
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

    test('the account state and the token state do not mix', () async {
      final phone = await FakeSyncDevice.create();
      await phone.diary.add({'id': 'm1'});
      await phone.engine.sync(token(phone), now: at(0));
      expect(phone.engine.hasLocalChanges(phone.accountState(userId)), isTrue);
      await phone.engine.sync(account(phone), now: at(1));
      await phone.tokenState.reset();
      expect(phone.tokenState.lastSync, isNull);
      expect(phone.accountState(userId).lastSync, isNotNull);
    });
  });

  group('pairing code', () {
    test('round-trips token and key', () {
      final code = pairing.encode();
      final parsed = SyncPairing.tryParse(code)!;
      expect(parsed.token, pairing.token);
      expect(parsed.key, pairing.key);
    });

    test('survives what copying between phone and computer does to it', () {
      final code = pairing.encode();
      final mid = code.length ~/ 2;
      final unpadded = code.replaceAll('=', '');
      final variants = {
        'line breaks and spaces': '${code.substring(0, mid)}\n ${code.substring(mid)}',
        'zero-width and no-break spaces': '​${code.substring(0, mid)} ${code.substring(mid)}﻿',
        'surrounding message text': 'Mi código: $code (no lo compartas)',
        'missing base64 padding': unpadded,
        'uppercase hex token': code.replaceFirst(pairing.token, pairing.token.toUpperCase()),
      };
      variants.forEach((label, raw) {
        final parsed = SyncPairing.tryParse(raw);
        expect(parsed, isNotNull, reason: label);
        expect(parsed!.token, pairing.token, reason: label);
        expect(parsed.key, pairing.key, reason: label);
      });
    });

    test('rejects bare backup tokens and garbage', () {
      expect(SyncPairing.tryParse('a' * 64), isNull);
      expect(SyncPairing.tryParse('ontsync1:nothex.AAAA'), isNull);
      expect(SyncPairing.tryParse('ontsync1:${'a' * 64}.AAAA'), isNull);
    });
  });
}
