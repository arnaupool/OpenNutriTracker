import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/account/account_key_crypto.dart';
import 'package:opennutritracker/core/account/account_key_envelope.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/account/account_key_remote.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';

/// Low counts keep these tests fast; only the "production defaults" group
/// uses the real ones.
AccountKeyCrypto _testCrypto() => AccountKeyCrypto.forTesting(passwordIterations: 1000, recoveryIterations: 100);

String _jwt(String sub) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': sub, 'role': 'authenticated'})}.signature';
}

/// Flips one bit of the decoded base64 field at [index].
String _flip(String b64, int index) {
  final bytes = base64Decode(b64);
  bytes[index] ^= 0x01;
  return base64Encode(bytes);
}

/// In-memory stand-in for PostgREST's `account_keys` with RLS: one row per
/// user, keyed by the token's subject.
class _FakeKeysServer {
  static const anonKey = 'anon-key';
  final rows = <String, Map<String, dynamic>>{};
  final requests = <http.Request>[];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final auth = request.headers['Authorization'] ?? '';
    if (request.headers['apikey'] != anonKey || !auth.startsWith('Bearer ')) {
      return http.Response('{"message":"unauthorized"}', 401);
    }
    final payload = auth.substring(7).split('.')[1];
    final user = (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload)))) as Map)['sub'] as String;
    final own = rows[user];
    switch (request.method) {
      case 'GET':
        return http.Response(jsonEncode([?own]), 200);
      case 'POST':
        if (own != null) return http.Response('{"code":"23505"}', 409);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        _checkConstraints(body);
        rows[user] = {'user_id': user, ...body};
        return http.Response('', 201);
      case 'PATCH':
        expect(request.url.queryParameters['user_id'], 'eq.$user');
        if (own == null) return http.Response('[]', 200);
        own.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        _checkConstraints(own);
        return http.Response(jsonEncode([own]), 200);
    }
    return http.Response('', 405);
  });

  /// The table's check constraints on base64 lengths.
  static void _checkConstraints(Map<String, dynamic> row) {
    expect((row['salt'] as String).length, inInclusiveRange(16, 128));
    expect((row['wrapped_key'] as String).length, inInclusiveRange(32, 256));
    if (row['recovery_salt'] != null) expect((row['recovery_salt'] as String).length, inInclusiveRange(16, 128));
    if (row['recovery_wrapped_key'] != null) {
      expect((row['recovery_wrapped_key'] as String).length, inInclusiveRange(32, 256));
    }
  }
}

void main() {
  group('AccountKeyCrypto password wrap', () {
    final crypto = _testCrypto();

    test('round trip returns the same data key', () async {
      final dataKey = crypto.newDataKey();
      expect(dataKey.length, 32);
      final wrap = await crypto.wrapWithPassword(dataKey, 'correct horse battery staple');
      expect(wrap.kdf, 'pbkdf2-sha256');
      expect(wrap.iterations, 1000);
      expect(base64Decode(wrap.salt).length, 16);
      expect(base64Decode(wrap.wrappedKey).length, 12 + 32 + 16);
      expect(await crypto.unwrapWithPassword(wrap.toEnvelope(), 'correct horse battery staple'), dataKey);
    });

    test('non-ASCII passwords round trip', () async {
      final dataKey = crypto.newDataKey();
      final wrap = await crypto.wrapWithPassword(dataKey, 'contraseña ñandú 🔑');
      expect(await crypto.unwrapWithPassword(wrap.toEnvelope(), 'contraseña ñandú 🔑'), dataKey);
    });

    test('wrong password throws WrongPasswordException', () async {
      final wrap = await crypto.wrapWithPassword(crypto.newDataKey(), 'right password');
      await expectLater(
        crypto.unwrapWithPassword(wrap.toEnvelope(), 'Right password'),
        throwsA(isA<WrongPasswordException>().having((e) => e.needsRewrap, 'needsRewrap', false)),
      );
    });

    test('wrong password on a row flagged needs_rewrap reports it', () async {
      final wrap = await crypto.wrapWithPassword(crypto.newDataKey(), 'old password');
      await expectLater(
        crypto.unwrapWithPassword(wrap.toEnvelope().copyWith(needsRewrap: true), 'new password'),
        throwsA(isA<WrongPasswordException>().having((e) => e.needsRewrap, 'needsRewrap', true)),
      );
    });

    test('a tampered wrapped_key (nonce, ciphertext or tag) throws', () async {
      final envelope = (await crypto.wrapWithPassword(crypto.newDataKey(), 'pw')).toEnvelope();
      for (final index in [0, 11, 12, 30, 43, 44, 59]) {
        await expectLater(
          crypto.unwrapWithPassword(envelope.copyWith(wrappedKey: _flip(envelope.wrappedKey, index)), 'pw'),
          throwsA(isA<WrongPasswordException>()),
          reason: 'byte $index',
        );
      }
    });

    test('a tampered salt or iteration count throws', () async {
      final envelope = (await crypto.wrapWithPassword(crypto.newDataKey(), 'pw')).toEnvelope();
      await expectLater(
        crypto.unwrapWithPassword(envelope.copyWith(salt: _flip(envelope.salt, 5)), 'pw'),
        throwsA(isA<WrongPasswordException>()),
      );
      await expectLater(
        crypto.unwrapWithPassword(envelope.copyWith(iterations: 1001), 'pw'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('follows the documented layout and rejects any other associated data', () async {
      // Built here with the package directly, so the format is checked
      // independently of the wrapping code.
      Future<AccountKeyEnvelope> manualWrap(Uint8List dataKey, String aad) async {
        final salt = Uint8List.fromList(List.generate(16, (i) => i));
        final kek = await Pbkdf2.hmacSha256(
          iterations: 1000,
          bits: 256,
        ).deriveKey(secretKey: SecretKey(utf8.encode('pw')), nonce: salt);
        final box = await AesGcm.with256bits().encrypt(
          dataKey,
          secretKey: kek,
          nonce: List.filled(12, 7),
          aad: ascii.encode(aad),
        );
        return AccountKeyEnvelope(
          iterations: 1000,
          salt: base64Encode(salt),
          wrappedKey: base64Encode(box.nonce + box.cipherText + box.mac.bytes),
        );
      }

      final dataKey = crypto.newDataKey();
      expect(await crypto.unwrapWithPassword(await manualWrap(dataKey, 'ont-account-key-v1'), 'pw'), dataKey);
      for (final aad in ['', 'ont-account-key-v2', 'ont-account-recovery-v1']) {
        await expectLater(
          crypto.unwrapWithPassword(await manualWrap(dataKey, aad), 'pw'),
          throwsA(isA<WrongPasswordException>()),
          reason: 'aad "$aad"',
        );
      }
    });

    test('two wraps of the same key use a fresh salt and nonce', () async {
      final dataKey = crypto.newDataKey();
      final a = await crypto.wrapWithPassword(dataKey, 'same password');
      final b = await crypto.wrapWithPassword(dataKey, 'same password');
      expect(a.salt, isNot(b.salt));
      expect(a.wrappedKey, isNot(b.wrappedKey));
      expect(base64Decode(a.wrappedKey).sublist(0, 12), isNot(base64Decode(b.wrappedKey).sublist(0, 12)));
      expect(await crypto.unwrapWithPassword(b.toEnvelope(), 'same password'), dataKey);
    });

    test('rewrap gives a new wrap that opens with the new password only', () async {
      final dataKey = crypto.newDataKey();
      final old = await crypto.wrapWithPassword(dataKey, 'old');
      final rewrapped = await crypto.rewrap(dataKey, 'new');
      expect(rewrapped.salt, isNot(old.salt));
      expect(await crypto.unwrapWithPassword(rewrapped.toEnvelope(), 'new'), dataKey);
      await expectLater(
        crypto.unwrapWithPassword(rewrapped.toEnvelope(), 'old'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('malformed or unknown rows are refused before any key derivation', () async {
      final envelope = (await crypto.wrapWithPassword(crypto.newDataKey(), 'pw')).toEnvelope();
      final bad = <String, AccountKeyEnvelope>{
        'kdf': envelope.copyWith(kdf: 'argon2id'),
        'version': envelope.copyWith(version: 2),
        'iterations too high': envelope.copyWith(iterations: 10000001),
        'iterations zero': envelope.copyWith(iterations: 0),
        'salt not base64': envelope.copyWith(salt: '!!not base64!!'),
        'salt too short': envelope.copyWith(salt: base64Encode(Uint8List(8))),
        'wrapped_key truncated': envelope.copyWith(
          wrappedKey: base64Encode(base64Decode(envelope.wrappedKey).sublist(0, 59)),
        ),
        'wrapped_key too long': envelope.copyWith(wrappedKey: base64Encode(Uint8List(61))),
      };
      for (final entry in bad.entries) {
        await expectLater(
          crypto.unwrapWithPassword(entry.value, 'pw'),
          throwsA(isA<InvalidEnvelopeException>()),
          reason: entry.key,
        );
      }
    });

    test('production crypto refuses rows below the table minimum of iterations', () async {
      final envelope = (await crypto.wrapWithPassword(crypto.newDataKey(), 'pw')).toEnvelope();
      await expectLater(
        AccountKeyCrypto().unwrapWithPassword(envelope, 'pw'),
        throwsA(isA<InvalidEnvelopeException>()),
      );
    });

    test('rejects a data key of the wrong length and an empty password', () async {
      await expectLater(crypto.wrapWithPassword(Uint8List(16), 'pw'), throwsArgumentError);
      await expectLater(crypto.wrapWithPassword(crypto.newDataKey(), ''), throwsArgumentError);
    });
  });

  group('AccountKeyCrypto recovery key', () {
    final crypto = _testCrypto();
    final format = RegExp(r'^([0-9A-HJKMNP-TV-Z]{4}-){7}[0-9A-HJKMNP-TV-Z]{4}$');

    test('generates 8 groups of 4 Crockford base32 characters (160 bits)', () {
      final keys = {for (var i = 0; i < 20; i++) crypto.generateRecoveryKey()};
      expect(keys, hasLength(20));
      for (final key in keys) {
        expect(key, matches(format));
        expect(AccountKeyCrypto.parseRecoveryKey(key).length, 20);
      }
    });

    test('formats and parses known bytes', () {
      expect(AccountKeyCrypto.formatRecoveryKey(Uint8List(20)), List.filled(8, '0000').join('-'));
      expect(
        AccountKeyCrypto.formatRecoveryKey(Uint8List.fromList(List.filled(20, 0xff))),
        List.filled(8, 'ZZZZ').join('-'),
      );
      // 0x08 0x42 = 00001 00001 00001 0... : '1' every 5 bits.
      final ones = Uint8List.fromList(List.generate(20, (i) => const [0x08, 0x42, 0x10, 0x84, 0x21][i % 5]));
      expect(AccountKeyCrypto.formatRecoveryKey(ones), List.filled(8, '1111').join('-'));
      expect(AccountKeyCrypto.parseRecoveryKey(List.filled(8, '1111').join('-')), ones);
    });

    test('round trip tolerates case, spaces, missing dashes and look-alikes', () async {
      final dataKey = crypto.newDataKey();
      final key = crypto.generateRecoveryKey();
      final wrap = await crypto.wrapWithRecoveryKey(dataKey, key);
      final envelope = (await crypto.wrapWithPassword(
        dataKey,
        'pw',
      )).toEnvelope().copyWith(recoverySalt: wrap.salt, recoveryWrappedKey: wrap.wrappedKey);
      final compact = key.replaceAll('-', '');
      final messy = [
        key,
        key.toLowerCase(),
        compact,
        ' ${compact.substring(0, 10)}  ${compact.substring(10).toLowerCase()}\n',
        key.split('-').join(' - '),
        key.replaceAll('0', 'o').replaceAll('1', 'l'),
        key.replaceAll('1', 'I').replaceAll('-', '‐'),
      ];
      for (final typed in messy) {
        expect(await crypto.unwrapWithRecoveryKey(envelope, typed), dataKey, reason: typed);
      }
    });

    test('a wrong recovery key throws WrongRecoveryKeyException', () async {
      final dataKey = crypto.newDataKey();
      final key = crypto.generateRecoveryKey();
      final wrap = await crypto.wrapWithRecoveryKey(dataKey, key);
      final envelope = (await crypto.wrapWithPassword(
        dataKey,
        'pw',
      )).toEnvelope().copyWith(recoverySalt: wrap.salt, recoveryWrappedKey: wrap.wrappedKey);
      await expectLater(
        crypto.unwrapWithRecoveryKey(envelope, crypto.generateRecoveryKey()),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
      // One character off (a typo) is a different key, not a format error.
      final typo = key.replaceRange(0, 1, key[0] == 'A' ? 'B' : 'A');
      await expectLater(crypto.unwrapWithRecoveryKey(envelope, typo), throwsA(isA<WrongRecoveryKeyException>()));
      // The right key against a tampered or re-salted recovery wrap.
      await expectLater(
        crypto.unwrapWithRecoveryKey(envelope.copyWith(recoveryWrappedKey: _flip(wrap.wrappedKey, 20)), key),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
      await expectLater(
        crypto.unwrapWithRecoveryKey(envelope.copyWith(recoverySalt: _flip(wrap.salt, 0)), key),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
    });

    test('malformed recovery keys are refused', () {
      final key = crypto.generateRecoveryKey();
      for (final bad in ['', key.substring(0, key.length - 1), '${key}Z', key.replaceRange(0, 1, 'U'), '$key!']) {
        expect(() => AccountKeyCrypto.parseRecoveryKey(bad), throwsA(isA<InvalidRecoveryKeyFormatException>()));
      }
    });

    test('recovery and password wraps cannot stand in for each other', () async {
      final dataKey = crypto.newDataKey();
      final key = crypto.generateRecoveryKey();
      final recovery = await crypto.wrapWithRecoveryKey(dataKey, key);
      final password = await crypto.wrapWithPassword(dataKey, 'pw');
      // The recovery wrap moved into the password columns.
      final swapped = AccountKeyEnvelope(iterations: 100, salt: recovery.salt, wrappedKey: recovery.wrappedKey);
      await expectLater(crypto.unwrapWithPassword(swapped, key), throwsA(isA<WrongPasswordException>()));
      // The password wrap moved into the recovery columns.
      final crossed = password.toEnvelope().copyWith(
        recoverySalt: password.salt,
        recoveryWrappedKey: password.wrappedKey,
      );
      await expectLater(crypto.unwrapWithRecoveryKey(crossed, key), throwsA(isA<WrongRecoveryKeyException>()));
    });

    test('a row without recovery key throws NoRecoveryKeyException', () async {
      final envelope = (await crypto.wrapWithPassword(crypto.newDataKey(), 'pw')).toEnvelope();
      await expectLater(
        crypto.unwrapWithRecoveryKey(envelope, crypto.generateRecoveryKey()),
        throwsA(isA<NoRecoveryKeyException>()),
      );
    });
  });

  group('AccountKeyEnvelope', () {
    test('JSON round trip uses the table column names', () {
      const envelope = AccountKeyEnvelope(
        iterations: 310000,
        salt: 'c2FsdHNhbHRzYWx0c2FsdA==',
        wrappedKey: 'd3JhcHBlZA==',
        recoverySalt: 'cmVjb3Zlcnk=',
        recoveryWrappedKey: 'cmVjd3JhcA==',
        needsRewrap: true,
      );
      final json = envelope.toJson();
      expect(json.keys, {
        'kdf',
        'iterations',
        'salt',
        'wrapped_key',
        'recovery_salt',
        'recovery_wrapped_key',
        'needs_rewrap',
        'version',
      });
      expect(json['kdf'], 'pbkdf2-sha256');
      expect(json['version'], 1);
      expect(AccountKeyEnvelope.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>), envelope);
    });

    test('reads a PostgREST row with extra columns and null recovery fields', () {
      final envelope = AccountKeyEnvelope.fromJson({
        'user_id': '00000000-0000-0000-0000-000000000001',
        'kdf': 'pbkdf2-sha256',
        'iterations': 310000,
        'salt': 'c2FsdA==',
        'wrapped_key': 'a2V5',
        'recovery_salt': null,
        'recovery_wrapped_key': null,
        'needs_rewrap': false,
        'version': 1,
        'updated_at': '2026-11-03T10:00:00+00:00',
      });
      expect(envelope.hasRecoveryKey, isFalse);
      expect(envelope.iterations, 310000);
    });

    test('rejects missing or mistyped columns', () {
      final good = const AccountKeyEnvelope(iterations: 1, salt: 's', wrappedKey: 'w').toJson();
      expect(() => AccountKeyEnvelope.fromJson({...good}..remove('salt')), throwsFormatException);
      expect(() => AccountKeyEnvelope.fromJson({...good, 'iterations': '310000'}), throwsFormatException);
    });

    test('toString does not print key material', () {
      const envelope = AccountKeyEnvelope(iterations: 1, salt: 'SALTSALT', wrappedKey: 'WRAPPEDKEY');
      expect(envelope.toString(), isNot(contains('SALTSALT')));
      expect(envelope.toString(), isNot(contains('WRAPPEDKEY')));
    });
  });

  group('AccountKeyService against a fake PostgREST', () {
    late _FakeKeysServer server;
    late AccountKeyService service;
    final token = _jwt('user-1');

    setUp(() {
      server = _FakeKeysServer();
      service = AccountKeyService(
        AccountKeyRemote('https://example.supabase.co/', _FakeKeysServer.anonKey, client: server.client),
        crypto: _testCrypto(),
      );
    });

    test('create stores a wrapped key, unlock returns it', () async {
      final dataKey = await service.createForNewAccount('first password', token);
      expect(dataKey.length, 32);
      final row = server.rows['user-1']!;
      expect(row['kdf'], 'pbkdf2-sha256');
      expect(row['needs_rewrap'], false);
      expect(row.values, isNot(contains(base64Encode(dataKey))));
      final post = server.requests.single;
      expect(post.url.toString(), 'https://example.supabase.co/rest/v1/account_keys');
      expect(post.headers['Authorization'], 'Bearer $token');
      expect(post.headers['apikey'], _FakeKeysServer.anonKey);
      expect(jsonDecode(post.body) as Map, isNot(contains('user_id')));

      expect(await service.unlock('first password', token), dataKey);
      await expectLater(service.unlock('wrong', token), throwsA(isA<WrongPasswordException>()));
    });

    test('create never replaces an existing key', () async {
      final first = await service.createForNewAccount('pw', token);
      final stored = Map.of(server.rows['user-1']!);
      await expectLater(service.createForNewAccount('pw', token), throwsA(isA<AccountKeyConflictException>()));
      expect(server.rows['user-1'], stored);
      expect(await service.unlock('pw', token), first);
    });

    test('unlock without a row throws AccountKeyNotFoundException', () async {
      await expectLater(service.unlock('pw', token), throwsA(isA<AccountKeyNotFoundException>()));
      expect(await service.fetchEnvelope(token), isNull);
    });

    test('changePassword: the old password stops working and the new one opens the same key', () async {
      final dataKey = await service.createForNewAccount('old password', token);
      await service.markNeedsRewrap(token);
      expect(server.rows['user-1']!['needs_rewrap'], true);

      await service.changePassword(dataKey, 'new password', token);
      final patch = server.requests.last;
      expect(patch.method, 'PATCH');
      expect(patch.url.queryParameters['user_id'], 'eq.user-1');
      expect(server.rows['user-1']!['needs_rewrap'], false);

      await expectLater(service.unlock('old password', token), throwsA(isA<WrongPasswordException>()));
      expect(await service.unlock('new password', token), dataKey);
    });

    test('a flagged row reports needsRewrap when the new password cannot open it', () async {
      await service.createForNewAccount('old password', token);
      await service.markNeedsRewrap(token);
      expect((await service.fetchEnvelope(token))!.needsRewrap, isTrue);
      await expectLater(
        service.unlock('password from the reset', token),
        throwsA(isA<WrongPasswordException>().having((e) => e.needsRewrap, 'needsRewrap', true)),
      );
    });

    test('changePassword without a row fails instead of reporting success', () async {
      await expectLater(
        service.changePassword(Uint8List(32), 'pw', token),
        throwsA(isA<AccountKeyNotFoundException>()),
      );
    });

    test('recovery key opens the key, survives a password change and can be replaced', () async {
      final dataKey = await service.createForNewAccount('pw', token);
      final recovery = await service.setRecoveryKey(dataKey, token);
      expect((await service.fetchEnvelope(token))!.hasRecoveryKey, isTrue);
      expect(await service.unlockWithRecoveryKey(recovery.toLowerCase().replaceAll('-', ' '), token), dataKey);

      await service.changePassword(dataKey, 'pw2', token);
      expect(await service.unlockWithRecoveryKey(recovery, token), dataKey);

      final replacement = await service.setRecoveryKey(dataKey, token);
      expect(await service.unlockWithRecoveryKey(replacement, token), dataKey);
      await expectLater(service.unlockWithRecoveryKey(recovery, token), throwsA(isA<WrongRecoveryKeyException>()));
    });

    test('server errors surface as AccountKeyRemoteException', () async {
      final failing = AccountKeyService(
        AccountKeyRemote(
          'https://example.supabase.co',
          'anon',
          client: MockClient((_) async => http.Response('{"message":"JWT expired"}', 401)),
        ),
        crypto: _testCrypto(),
      );
      await expectLater(
        failing.unlock('pw', token),
        throwsA(isA<AccountKeyRemoteException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      await expectLater(failing.createForNewAccount('pw', token), throwsA(isA<AccountKeyRemoteException>()));
    });

    test('a malformed row from the server is refused', () async {
      final broken = AccountKeyService(
        AccountKeyRemote(
          'https://example.supabase.co',
          'anon',
          client: MockClient((_) async => http.Response('[{"kdf":"pbkdf2-sha256"}]', 200)),
        ),
        crypto: _testCrypto(),
      );
      await expectLater(broken.unlock('pw', token), throwsA(isA<InvalidEnvelopeException>()));
    });
  });

  group('production defaults', () {
    test('310000 iterations, row fits the table constraints, and timing', () async {
      final crypto = AccountKeyCrypto();
      final dataKey = crypto.newDataKey();

      final rawWatch = Stopwatch()..start();
      await Pbkdf2.hmacSha256(
        iterations: AccountKeyCrypto.defaultPasswordIterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode('benchmark')), nonce: Uint8List(16));
      final raw = rawWatch.elapsed;

      final wrapWatch = Stopwatch()..start();
      final wrap = await crypto.wrapWithPassword(dataKey, 'a real password');
      final wrapTime = wrapWatch.elapsed;

      final unwrapWatch = Stopwatch()..start();
      expect(await crypto.unwrapWithPassword(wrap.toEnvelope(), 'a real password'), dataKey);
      final unwrapTime = unwrapWatch.elapsed;

      expect(wrap.iterations, 310000);
      final row = wrap.toEnvelope().toJson();
      expect(row['iterations'], inInclusiveRange(100000, 10000000));
      expect((row['salt'] as String).length, inInclusiveRange(16, 128));
      expect((row['wrapped_key'] as String).length, inInclusiveRange(32, 256));

      final recovery = await crypto.wrapWithRecoveryKey(dataKey, crypto.generateRecoveryKey());
      expect(recovery.salt.length, inInclusiveRange(16, 128));
      expect(recovery.wrappedKey.length, inInclusiveRange(32, 256));

      // ignore: avoid_print
      print(
        'PBKDF2-HMAC-SHA256 x310000 on the VM: raw ${raw.inMilliseconds} ms, '
        'wrap ${wrapTime.inMilliseconds} ms, unwrap ${unwrapTime.inMilliseconds} ms (isolate included)',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
