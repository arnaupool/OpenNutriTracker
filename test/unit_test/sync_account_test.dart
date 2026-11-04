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
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

import '../helpers/fake_sync_server.dart';

const _profile = 'p1';
const _userId = 'user-1';

String _jwt(String sub, [String jti = 'a']) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub, 'jti': jti})}.sig';
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
  final accounts = _FakeAccounts();
  final accountSets = <String>[];
  final photoSyncs = <String>[];
  bool photoSyncFails = false;
  late final SyncService service = SyncService(
    engine: device.engine,
    accounts: accounts,
    stateBox: device.stateBox,
    boxes: device.engine.boxes,
    accountRemote: (userId, token) {
      accountSets.add(userId);
      return _GuardedRemote(server.remote(userId), token);
    },
    onApplied: (_) async {},
    afterAccountSync: (profileId, userId, key, accessToken) async {
      photoSyncs.add('$profileId/$userId');
      if (photoSyncFails) throw StateError('photo service down');
    },
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
    test('a local profile does not sync at all', () async {
      final h = await _Harness.create(server);
      await h.device.diary.add({'id': 'm1'});
      expect(await h.service.syncNow(), isNull);
      expect(h.service.status.value.phase, SyncPhase.off);
      expect(h.accountSets, isEmpty);
      expect(server.rows, isEmpty);
    });

    test('a profile that was paired with the removed QR sync simply stops syncing', () async {
      final h = await _Harness.create(server);
      await h.device.diary.add({'id': 'm1'});
      // Old per-profile secrets and token state are ignored, not read.
      await h.device.stateBox.put('cursor', '2026-01-01T00:00:00.000Z');
      await h.device.stateBox.put('hashes:diary', {'m1': 'x'});
      expect(await h.service.syncNow(), isNull);
      expect(h.service.status.value.phase, SyncPhase.off);
      expect(server.rows, isEmpty);
      expect(h.device.diary.length, 1);
    });

    test('a ready account syncs through account_records only', () async {
      final h = await _Harness.create(server);
      h.link();
      await h.device.diary.add({'id': 'm1', 'kcal': 5});
      final result = await h.service.syncNow();
      expect(result!.pushed, 1);
      expect(h.accountRecords().keys, ['m1']);
      expect(h.service.status.value.phase, SyncPhase.idle);
      expect(h.service.status.value.lastSync, isNotNull);
    });

    test('photo sync runs after an account sync only, and its failure is not a sync error', () async {
      final local = await _Harness.create(server);
      await local.service.syncNow();
      expect(local.photoSyncs, isEmpty);

      final h = await _Harness.create(server);
      h.link();
      h.photoSyncFails = true;
      expect(await h.service.syncNow(), isNotNull);
      expect(h.photoSyncs, ['$_profile/$_userId']);
      expect(h.service.status.value.phase, SyncPhase.idle);
    });

    test('an account that is not ready sends nothing and reports why', () async {
      for (final st in [AccountStatus.signedOut, AccountStatus.needsRewrap]) {
        final h = await _Harness.create(server);
        h.link();
        h.accounts.accountStatus = st;
        await h.device.diary.add({'id': 'm1'});
        expect(await h.service.syncNow(), isNull);
        expect(h.service.status.value.phase, SyncPhase.error);
        expect((h.service.status.value.error! as AccountSyncUnavailableException).status, st);
        expect(h.accountSets, isEmpty);
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
        SyncTarget(remote: server.remote(_userId), state: stale.accountState(_userId), key: oldKey),
      );

      expect(await h.service.startFresh(_profile, 'new password'), isTrue);
      expect(h.accounts.startFreshPassword, 'new password');
      expect(h.accounts.key, isNot(oldKey));
      expect(h.accountRecords().keys, ['kept-locally'], reason: 'readable with the new key');
      expect(await h.service.hasPendingChanges(_profile), isFalse);

      await expectLater(
        stale.engine.sync(SyncTarget(remote: server.remote(_userId), state: stale.accountState(_userId), key: oldKey)),
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
      final remote = AccountSyncRemote('https://x.supabase.co', 'anon', _userId, tokens([]), client: client);
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
