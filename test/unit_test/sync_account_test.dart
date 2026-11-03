import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

import '../helpers/fake_sync_server.dart';

const _profile = 'p1';
const _userId = 'user-1';

String _jwt(String sub, [String jti = 'a']) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub, 'jti': jti})}.sig';
}

class _FakePairings implements SyncKeyService {
  SyncPairing? pairing;
  bool forgotten = false;

  @override
  Future<SyncPairing?> read() async => pairing;

  @override
  Future<bool> isEnabled() async => pairing != null;

  @override
  Future<SyncPairing> enable() async => pairing ??= SyncPairing('b' * 64, SyncCrypto.generateKey());

  @override
  Future<void> store(SyncPairing value) async => pairing = value;

  @override
  Future<void> disable() async => pairing = null;

  @override
  Future<void> forget() async {
    pairing = null;
    forgotten = true;
  }
}

/// The parts of [AccountSessionService] sync uses.
class _FakeAccounts implements AccountSessionService {
  AccountLink? linked;
  AccountStatus accountStatus = AccountStatus.ready;
  Uint8List? key = SyncCrypto.generateKey();
  bool signedIn = true;
  int tokenCalls = 0;
  int forcedRefreshes = 0;
  String? startFreshPassword;

  @override
  Future<AccountLink?> link(String profileId) async => profileId == _profile ? linked : null;

  @override
  Future<AccountStatus> status(String profileId) async => linked == null ? AccountStatus.local : accountStatus;

  @override
  Future<Uint8List?> dataKey(String profileId) async => linked == null ? null : key;

  @override
  Future<String> accessToken(String profileId, {bool forceRefresh = false}) async {
    tokenCalls++;
    if (!signedIn) throw const NotSignedInException();
    if (forceRefresh) forcedRefreshes++;
    return _jwt(_userId, 't$forcedRefreshes');
  }

  @override
  Future<Uint8List> startFresh(
    String profileId,
    String password, {
    String? email,
    required Future<void> Function(String accessToken, String userId) deleteRecords,
  }) async {
    startFreshPassword = password;
    await deleteRecords(_jwt(_userId, 'fresh'), _userId);
    linked = const AccountLink(userId: _userId, email: 'ana@example.com');
    return key = SyncCrypto.generateKey();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// The in-memory account set behind the same token rule as
/// [AccountSyncRemote]: no token, no request.
class _GuardedRemote implements SyncRemote {
  final FakeSyncRemote inner;
  final AccessTokenSource token;

  _GuardedRemote(this.inner, this.token);

  @override
  Future<List<SyncRow>> pull({DateTime? since, SyncRow? after, int limit = 500}) async {
    await token();
    return inner.pull(since: since, after: after, limit: limit);
  }

  @override
  Future<void> push(List<SyncRow> rows) async {
    await token();
    return inner.push(rows);
  }

  @override
  Future<SyncRow?> fetch(String box, String id) async {
    await token();
    return inner.fetch(box, id);
  }

  @override
  Future<void> deleteAll() async {
    await token();
    return inner.deleteAll();
  }
}

class _Harness {
  final FakeSyncServer server;
  final FakeSyncDevice device;
  final pairings = _FakePairings();
  final accounts = _FakeAccounts();
  final tokenSets = <String>[];
  final accountSets = <String>[];
  late final SyncService service = SyncService(
    engine: device.engine,
    pairings: pairings,
    accounts: accounts,
    stateBox: device.stateBox,
    boxes: device.engine.boxes,
    tokenRemote: (token) {
      tokenSets.add(token);
      return server.remote(token);
    },
    accountRemote: (userId, token) {
      accountSets.add(userId);
      return _GuardedRemote(server.remote(userId), token);
    },
    onApplied: (_) async {},
    activeProfile: () => _profile,
  );

  _Harness(this.server, this.device);

  static Future<_Harness> create(FakeSyncServer server) async => _Harness(server, await FakeSyncDevice.create());

  void link() => accounts.linked = const AccountLink(userId: _userId, email: 'ana@example.com');

  /// Decrypts the account's rows with the account key: identity → JSON.
  Map<String, String?> accountRecords() {
    final crypto = SyncCrypto(accounts.key!);
    return {
      for (final row in server.rowsOf(_userId))
        if (row.box != SyncEngine.keyCheckBox)
          (jsonDecode(crypto.decrypt(row.payload!)) as Map)['i'] as String:
              (jsonDecode(crypto.decrypt(row.payload!)) as Map)['v'] as String?,
    };
  }
}

void main() {
  late FakeSyncServer server;

  setUp(() => server = FakeSyncServer());

  group('which path a profile uses', () {
    test('a local profile without a pairing does not sync at all', () async {
      final h = await _Harness.create(server);
      await h.device.diary.add({'id': 'm1'});
      expect(await h.service.syncNow(), isNull);
      expect(h.service.status.value.phase, SyncPhase.off);
      expect(h.tokenSets, isEmpty);
      expect(h.accountSets, isEmpty);
      expect(server.rows, isEmpty);
    });

    test('a local profile with an old pairing keeps the token path', () async {
      final h = await _Harness.create(server);
      h.pairings.pairing = SyncPairing('c' * 64, SyncCrypto.generateKey());
      await h.device.diary.add({'id': 'm1'});
      final result = await h.service.syncNow();
      expect(result!.pushed, 1);
      expect(server.rowsOf('c' * 64), hasLength(1));
      expect(h.accountSets, isEmpty);
      expect(h.pairings.pairing, isNotNull);
    });

    test('a ready account syncs through account_records only', () async {
      final h = await _Harness.create(server);
      h.link();
      await h.device.diary.add({'id': 'm1', 'kcal': 5});
      final result = await h.service.syncNow();
      expect(result!.pushed, 1);
      expect(h.tokenSets, isEmpty);
      expect(h.accountRecords().keys, ['m1']);
      expect(h.service.status.value.phase, SyncPhase.idle);
      expect(h.service.status.value.lastSync, isNotNull);
    });

    test('an account that is not ready sends nothing and reports why', () async {
      for (final st in [AccountStatus.signedOut, AccountStatus.needsRewrap]) {
        final h = await _Harness.create(server);
        h.link();
        h.accounts.accountStatus = st;
        h.pairings.pairing = SyncPairing('d' * 64, SyncCrypto.generateKey());
        await h.device.diary.add({'id': 'm1'});
        expect(await h.service.syncNow(), isNull);
        expect(h.service.status.value.phase, SyncPhase.error);
        expect((h.service.status.value.error! as AccountSyncUnavailableException).status, st);
        expect(h.accountSets, isEmpty);
        expect(h.tokenSets, isEmpty, reason: 'an account profile never falls back to its pairing');
      }
      expect(server.rows, isEmpty);
    });

    test('without an access token no request goes out', () async {
      final h = await _Harness.create(server);
      h.link();
      h.accounts.signedIn = false;
      await h.device.diary.add({'id': 'm1'});
      expect(await h.service.syncNow(), isNull);
      expect(h.service.status.value.phase, SyncPhase.error);
      expect(h.service.status.value.error, isA<NotSignedInException>());
      expect(server.rows, isEmpty);
      expect(server.pulls + server.pushes, 0);
    });

    test('an account profile cannot start a new pairing', () async {
      final h = await _Harness.create(server);
      h.link();
      await expectLater(h.service.enableAsOwner(), throwsStateError);
      expect(h.pairings.pairing, isNull);
    });
  });

  group('migration from an old pairing', () {
    late SyncPairing pairing;

    setUp(() => pairing = SyncPairing('e' * 64, SyncCrypto.generateKey()));

    /// Another device of the same token set with a record of its own.
    Future<void> otherDeviceWrites(String id) async {
      final other = await FakeSyncDevice.create();
      await other.diary.add({'id': id});
      await other.engine.sync(
        SyncTarget(remote: server.remote(pairing.token), state: other.tokenState, key: pairing.key),
      );
    }

    test('uploads and merges everything, then deletes the token rows and forgets the pairing', () async {
      final h = await _Harness.create(server);
      h.pairings.pairing = pairing;
      await h.device.diary.add({'id': 'local'});
      await h.service.syncNow();
      await otherDeviceWrites('from-other-device');
      expect(server.rowsOf(pairing.token), hasLength(2));

      h.link();
      final result = await h.service.syncNow();
      expect(result, isNotNull);
      expect(h.accountRecords().keys, unorderedEquals(['local', 'from-other-device']));
      expect(h.device.entries.keys, unorderedEquals(['local', 'from-other-device']));
      expect(server.rowsOf(pairing.token), isEmpty);
      expect(h.pairings.forgotten, isTrue);
      expect(h.device.tokenState.lastSync, isNull);
      expect(await h.service.hasPendingChanges(_profile), isFalse);
    });

    test('a failed account push keeps the token rows and the pairing', () async {
      final h = await _Harness.create(server);
      h.pairings.pairing = pairing;
      await h.device.diary.add({'id': 'local'});
      await h.service.syncNow();
      h.link();

      server.failPush = true;
      expect(await h.service.syncNow(), isNull);
      expect(h.service.status.value.phase, SyncPhase.error);
      expect(server.rowsOf(pairing.token), hasLength(1));
      expect(server.deletes, 0);
      expect(h.pairings.pairing, isNotNull);

      server.failPush = false;
      expect(await h.service.syncNow(), isNotNull);
      expect(server.rowsOf(pairing.token), isEmpty);
      expect(h.pairings.forgotten, isTrue);
    });

    test('a failed delete keeps the pairing and is retried after the next account sync', () async {
      final h = await _Harness.create(server);
      h.pairings.pairing = pairing;
      await h.device.diary.add({'id': 'local'});
      await h.service.syncNow();
      h.link();

      server.failDelete = true;
      expect(await h.service.syncNow(), isNotNull);
      expect(h.service.status.value.phase, SyncPhase.idle);
      expect(h.accountRecords().keys, ['local']);
      expect(server.rowsOf(pairing.token), hasLength(1));
      expect(h.pairings.pairing, isNotNull);

      server.failDelete = false;
      await h.service.syncNow();
      expect(server.rowsOf(pairing.token), isEmpty);
      expect(h.pairings.forgotten, isTrue);
    });
  });

  group('sign-out safety', () {
    test('hasPendingChanges and syncBeforeSignOut', () async {
      final h = await _Harness.create(server);
      expect(await h.service.hasPendingChanges(_profile), isFalse, reason: 'local profile');
      expect(await h.service.syncBeforeSignOut(_profile), isFalse, reason: 'nothing of a local profile is on a server');

      h.link();
      expect(await h.service.hasPendingChanges(_profile), isFalse);
      await h.device.diary.add({'id': 'm1'});
      expect(await h.service.hasPendingChanges(_profile), isTrue);
      expect(await h.service.syncBeforeSignOut(_profile), isTrue);
      expect(await h.service.hasPendingChanges(_profile), isFalse);

      await h.device.putEntry('m1', {'kcal': 9});
      expect(await h.service.hasPendingChanges(_profile), isTrue);
      server.failPush = true;
      expect(await h.service.syncBeforeSignOut(_profile), isFalse);
      expect(await h.service.hasPendingChanges(_profile), isTrue);
      server.failPush = false;
      expect(await h.service.syncBeforeSignOut(_profile), isTrue);
    });

    test('only the active profile', () async {
      final h = await _Harness.create(server);
      expect(() => h.service.hasPendingChanges('other'), throwsStateError);
      expect(() => h.service.syncBeforeSignOut('other'), throwsStateError);
    });
  });

  group('start from scratch', () {
    test('deletes the account rows, pushes local data under the new key, and stops old-key devices', () async {
      final h = await _Harness.create(server);
      h.link();
      final oldKey = h.accounts.key!;
      await h.device.diary.add({'id': 'kept-locally'});
      await h.service.syncNow();

      // Another device of the account, still holding the old key.
      final stale = await FakeSyncDevice.create();
      await stale.engine.sync(
        SyncTarget(remote: server.remote(_userId), state: stale.accountState(_userId), key: oldKey, account: true),
      );

      expect(await h.service.startFresh(_profile, 'new password'), isTrue);
      expect(h.accounts.startFreshPassword, 'new password');
      expect(h.accounts.key, isNot(oldKey));
      expect(h.accountRecords().keys, ['kept-locally'], reason: 'readable with the new key');
      expect(await h.service.hasPendingChanges(_profile), isFalse);

      await expectLater(
        stale.engine.sync(
          SyncTarget(remote: server.remote(_userId), state: stale.accountState(_userId), key: oldKey, account: true),
        ),
        throwsA(isA<SyncKeyMismatchException>()),
      );
    });
  });

  group('AccountSyncRemote over HTTP', () {
    Future<String> Function({bool forceRefresh}) tokens(List<bool> calls, {String sub = _userId}) =>
        ({bool forceRefresh = false}) async {
          calls.add(forceRefresh);
          return _jwt(sub, 'call${calls.length}');
        };

    test('sends apikey and Bearer to account_records, user_id on every row', () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response(r.method == 'GET' ? '[]' : '', r.method == 'GET' ? 200 : 201);
      });
      final remote = AccountSyncRemote('https://x.supabase.co/', 'anon', _userId, tokens([]), client: client);
      await remote.pull();
      await remote.push([SyncRow(box: 'b', id: 'i', payload: 'p', modifiedAt: DateTime.utc(2026))]);
      expect(requests.map((r) => r.url.path), everyElement('/rest/v1/account_records'));
      for (final r in requests) {
        expect(r.headers['apikey'], 'anon');
        expect(r.headers['Authorization'], startsWith('Bearer '));
        expect(r.headers.containsKey('x-sync-token'), isFalse);
      }
      expect(requests.last.url.queryParameters['on_conflict'], 'user_id,box,id');
      expect((jsonDecode(requests.last.body) as List).single['user_id'], _userId);
    });

    test('a 401 refreshes the token once and retries', () async {
      final calls = <bool>[];
      final seen = <String>[];
      final client = MockClient((r) async {
        seen.add(r.headers['Authorization']!);
        return seen.length == 1 ? http.Response('{"message":"JWT expired"}', 401) : http.Response('[]', 200);
      });
      final remote = AccountSyncRemote('https://x.supabase.co', 'anon', _userId, tokens(calls), client: client);
      expect(await remote.pull(), isEmpty);
      expect(calls, [false, true]);
      expect(seen[0], isNot(seen[1]));
    });

    test('a second 401 is an error, without a third try', () async {
      final calls = <bool>[];
      var sent = 0;
      final client = MockClient((r) async {
        sent++;
        return http.Response('{"message":"JWT expired"}', 401);
      });
      final remote = AccountSyncRemote('https://x.supabase.co', 'anon', _userId, tokens(calls), client: client);
      await expectLater(remote.pull(), throwsA(isA<SyncRemoteException>().having((e) => e.statusCode, 'status', 401)));
      expect(sent, 2);
      expect(calls, [false, true]);
    });

    test('no token, or a token of another user: nothing is sent', () async {
      var sent = 0;
      final client = MockClient((r) async {
        sent++;
        return http.Response('[]', 200);
      });
      final signedOut = AccountSyncRemote(
        'https://x.supabase.co',
        'anon',
        _userId,
        ({bool forceRefresh = false}) async => throw const NotSignedInException(),
        client: client,
      );
      await expectLater(signedOut.push([]), completes, reason: 'an empty push needs no request');
      await expectLater(
        signedOut.push([SyncRow(box: 'b', id: 'i', payload: 'p', modifiedAt: DateTime.utc(2026))]),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(signedOut.pull(), throwsA(isA<NotSignedInException>()));
      final wrongUser = AccountSyncRemote(
        'https://x.supabase.co',
        'anon',
        _userId,
        tokens([], sub: 'someone-else'),
        client: client,
      );
      await expectLater(wrongUser.pull(), throwsA(isA<AccountTokenMismatchException>()));
      expect(sent, 0);
    });

    test('pages after the first use a keyset on the exact server time', () async {
      final queries = <Map<String, String>>[];
      final client = MockClient((r) async {
        queries.add(r.url.queryParameters);
        return http.Response('[]', 200);
      });
      final remote = TokenSyncRemote('https://x.supabase.co', 'anon', 'f' * 64, client: client);
      final last = SyncRow.fromJson({
        'box': 'bx',
        'id': 'id1',
        'payload': null,
        'modified_at': '2026-11-03T10:00:00+00:00',
        'updated_at': '2026-11-03T10:00:00.123456+00:00',
        'deleted': false,
      });
      await remote.pull(after: last);
      expect(queries.single['order'], 'updated_at.asc,box.asc,id.asc');
      expect(queries.single['or'], contains('updated_at.eq."2026-11-03T10:00:00.123456+00:00"'));
      expect(queries.single['or'], contains('id.gt."id1"'));
    });
  });
}
