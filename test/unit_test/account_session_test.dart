import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/account/account_auth_api.dart';
import 'package:opennutritracker/core/account/account_auth_secret.dart';
import 'package:opennutritracker/core/account/account_key_crypto.dart';
import 'package:opennutritracker/core/account/account_key_envelope.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/account/account_key_remote.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/account/account_session_store.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:pointycastle/export.dart';

const _url = 'https://project.supabase.co';
const _anon = 'anon-key';

AccountKeyCrypto _crypto() => AccountKeyCrypto.forTesting(passwordIterations: 1000, recoveryIterations: 100);
const _secret = AccountAuthSecret.forTesting(iterations: 1000);

String _jwt(String sub, String jti) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': sub, 'jti': jti})}.signature';
}

String _subOf(String jwt) =>
    (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1])))) as Map)['sub'] as String;

/// In-memory secure storage, one per simulated device.
class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        value == null ? values.remove(key) : values[key!] = value;
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
      case #containsKey:
        return Future<bool>.value(values.containsKey(key));
    }
    return super.noSuchMethod(invocation);
  }
}

class _User {
  final String id;
  final String email;
  String secret;
  bool confirmed = false;
  String? signupCode;
  String? recoveryCode;

  _User(this.id, this.email, this.secret);
}

class _Session {
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  bool revoked = false;

  _Session(this.userId, this.accessToken, this.refreshToken, this.expiresAt);
}

/// Supabase Auth (GoTrue) plus the two PostgREST tables the service reads,
/// in memory, with refresh-token rotation and RLS by token subject.
class _FakeSupabase {
  DateTime now = DateTime.utc(2026, 11, 3, 12);
  bool signupsOpen = true;

  /// Overrides [signupsOpen] per read of `app_settings` (0 is the first).
  bool Function(int read)? signupsOpenAt;
  var _settingsReads = 0;

  /// The before-insert trigger, independent of what `app_settings` says.
  String? signupGateError;
  bool failPasswordUpdates = false;
  bool autoConfirm = false;

  final users = <String, _User>{};
  final sessions = <String, _Session>{};
  final keyRows = <String, Map<String, dynamic>>{};
  final requests = <http.Request>[];
  var _seq = 0;

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    if (request.headers['apikey'] != _anon) return _json(401, {'message': 'no apikey'});
    final path = request.url.path;
    if (path == '/rest/v1/app_settings') {
      return _json(200, [
        {'signups_open': signupsOpenAt?.call(_settingsReads++) ?? signupsOpen},
      ]);
    }
    if (path == '/rest/v1/account_keys') return _keys(request);
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
    switch (path) {
      case '/auth/v1/signup':
        if (signupGateError != null) {
          return _json(500, {'code': 500, 'error_code': 'unexpected_failure', 'msg': signupGateError});
        }
        final email = body['email'] as String;
        final user = users.putIfAbsent(email, () => _User('user-${_seq++}', email, body['password'] as String));
        if (autoConfirm) {
          user.confirmed = true;
          return _json(200, _issue(user));
        }
        user.signupCode = '${100000 + _seq++}';
        return _json(200, {'id': user.id, 'email': email});
      case '/auth/v1/resend':
        final user = users[body['email']];
        if (user != null) user.signupCode = '${100000 + _seq++}';
        return _json(200, {});
      case '/auth/v1/verify':
        final user = users[body['email']];
        final type = body['type'];
        final expected = type == 'signup' ? user?.signupCode : (type == 'recovery' ? user?.recoveryCode : null);
        if (user == null || expected == null || expected != body['token']) {
          return _json(403, {'code': 403, 'error_code': 'otp_expired', 'msg': 'Token has expired or is invalid'});
        }
        if (type == 'signup') {
          user.confirmed = true;
          user.signupCode = null;
        } else {
          user.recoveryCode = null;
        }
        return _json(200, _issue(user));
      case '/auth/v1/token':
        if (request.url.queryParameters['grant_type'] == 'password') {
          final user = users[body['email']];
          if (user == null || user.secret != body['password']) {
            return _json(400, {'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'});
          }
          if (!user.confirmed) {
            return _json(400, {'code': 400, 'error_code': 'email_not_confirmed', 'msg': 'Email not confirmed'});
          }
          return _json(200, _issue(user));
        }
        final old = sessions.values.where((s) => s.refreshToken == body['refresh_token'] && !s.revoked).firstOrNull;
        if (old == null) {
          return _json(400, {
            'code': 400,
            'error_code': 'refresh_token_not_found',
            'msg': 'Invalid Refresh Token: Refresh Token Not Found',
          });
        }
        old.revoked = true;
        return _json(200, _issue(users.values.firstWhere((u) => u.id == old.userId)));
      case '/auth/v1/recover':
        final user = users[body['email']];
        if (user != null) user.recoveryCode = '${200000 + _seq++}';
        return _json(200, {});
      case '/auth/v1/user':
        final session = _bearer(request);
        if (session == null) return _json(401, {'code': 401, 'error_code': 'bad_jwt', 'msg': 'invalid JWT'});
        if (failPasswordUpdates) return _json(500, {'code': 500, 'error_code': 'unexpected_failure', 'msg': 'boom'});
        final user = users.values.firstWhere((u) => u.id == session.userId);
        if (user.secret == body['password']) {
          return _json(422, {'code': 422, 'error_code': 'same_password', 'msg': 'same password'});
        }
        user.secret = body['password'] as String;
        return _json(200, {'id': user.id, 'email': user.email});
      case '/auth/v1/logout':
        final token = (request.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
        sessions[token]?.revoked = true;
        return http.Response('', 204);
    }
    return _json(404, {'msg': 'no route $path'});
  });

  Map<String, dynamic> _issue(_User user) {
    final access = _jwt(user.id, 'j${_seq++}');
    final refresh = 'refresh-${_seq++}';
    final expiresAt = now.add(const Duration(hours: 1));
    sessions[access] = _Session(user.id, access, refresh, expiresAt);
    return {
      'access_token': access,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'refresh_token': refresh,
      'user': {'id': user.id, 'email': user.email},
    };
  }

  /// A known, unexpired access token (PostgREST and GoTrue check only the
  /// JWT, so a revoked session's access token still works until it expires).
  _Session? _bearer(http.Request request) {
    final token = (request.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
    final session = sessions[token];
    if (session == null || !now.isBefore(session.expiresAt)) return null;
    return session;
  }

  http.Response _keys(http.Request request) {
    final session = _bearer(request);
    if (session == null) return _json(401, {'message': 'JWT expired'});
    final own = keyRows[session.userId];
    switch (request.method) {
      case 'GET':
        return _json(200, [?own]);
      case 'POST':
        if (own != null) return _json(409, {'code': '23505'});
        keyRows[session.userId] = {'user_id': session.userId, ...jsonDecode(request.body) as Map<String, dynamic>};
        return http.Response('', 201);
      case 'PATCH':
        if (own == null) return _json(200, []);
        own.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(200, [own]);
    }
    return _json(405, {});
  }

  _User user(String email) => users[email]!;

  AccountKeyEnvelope envelope(String email) => AccountKeyEnvelope.fromJson(keyRows[user(email).id]!);

  bool liveRefreshToken(String refreshToken) =>
      sessions.values.any((s) => s.refreshToken == refreshToken && !s.revoked);

  /// Every request body the server received, for "the password never left
  /// the device" checks.
  Iterable<String> get bodies => requests.map((r) => r.body);

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

class _Device {
  final _FakeSupabase server;
  final storage = _MemoryStorage();
  late final profiles = ProfileStore(storage: storage);
  late final store = AccountSessionStore(storage: storage);
  late final keys = AccountKeyService(AccountKeyRemote(_url, _anon, client: server.client), crypto: _crypto());
  late final service = AccountSessionService(
    api: AccountAuthApi(_url, _anon, client: server.client, now: () => server.now),
    keys: keys,
    store: store,
    profiles: profiles,
    secret: _secret,
    now: () => server.now,
  );

  _Device(this.server);

  /// Creates and confirms an account on [profileId].
  Future<void> createAccount(String profileId, String email, String password) async {
    expect(await service.signUp(profileId, email, password), SignUpResult.codeSent);
    final code = server.user(AccountAuthSecret.normalizeEmail(email)).signupCode!;
    expect(await service.verifySignupCode(profileId, email, code, password), SignInResult.ready);
  }

  Future<String> newProfile([String name = 'p']) async => (await profiles.add(name)).id;
}

const _email = 'ana@example.com';
const _pw = 'correct horse battery staple';
const _newPw = 'new password 2026';

Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))..init(Pbkdf2Parameters(salt, iterations, 32));
  return kdf.process(password);
}

Uint8List _hkdf(Uint8List ikm, Uint8List info) {
  final kdf = HKDFKeyDerivator(SHA256Digest())..init(HkdfParameters(ikm, 32, null, info));
  final out = Uint8List(32);
  kdf.deriveKey(null, 0, out, 0);
  return out;
}

void main() {
  group('AccountAuthSecret', () {
    test('differs from the password, is unpadded base64url and deterministic', () async {
      final a = await _secret.derive(_pw, _email);
      final b = await _secret.derive(_pw, _email);
      expect(a, b);
      expect(a, isNot(_pw));
      expect(a, isNot(contains(_pw)));
      expect(a.length, 43);
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    });

    test('depends on the email only up to case and surrounding spaces', () async {
      final lower = await _secret.derive(_pw, 'a@x.com');
      expect(await _secret.derive(_pw, 'A@x.com'), lower);
      expect(await _secret.derive(_pw, '  A@X.COM '), lower);
      expect(await _secret.derive(_pw, 'b@x.com'), isNot(lower));
      expect(await _secret.derive('${_pw}x', 'a@x.com'), isNot(lower));
    });

    test('matches an independent PBKDF2 + HKDF computation', () async {
      final master = _pbkdf2(utf8.encode('contraseña 🔑'), utf8.encode('ont-auth-v1:a@x.com'), 1000);
      final expected = base64Url.encode(_hkdf(master, utf8.encode('ont-auth-v1'))).replaceAll('=', '');
      expect(await _secret.derive('contraseña 🔑', 'A@x.com'), expected);
    });

    test('production uses 310000 iterations', () {
      expect(const AccountAuthSecret().iterations, 310000);
    });
  });

  group('AppProfile account link', () {
    test('profiles stored before accounts read back as local', () async {
      final storage = _MemoryStorage()
        ..values['Profiles'] = jsonEncode([
          {'id': 'default', 'name': 'Me'},
          {'id': 'abc', 'name': 'Other'},
        ]);
      final profiles = await ProfileStore(storage: storage).all();
      expect(profiles.map((p) => p.isLocal), [true, true]);
      expect(profiles.map((p) => p.name), ['Me', 'Other']);
    });

    test('the link round trips and survives a rename; null unlinks', () async {
      final store = ProfileStore(storage: _MemoryStorage());
      final p = await store.add('Work');
      const link = AccountLink(userId: 'u1', email: 'a@x.com');
      await store.setAccount(p.id, link);
      await store.rename(p.id, 'Job');
      final read = (await store.byId(p.id))!;
      expect(read.name, 'Job');
      expect(read.account, link);
      await store.setAccount(p.id, null);
      expect((await store.byId(p.id))!.isLocal, isTrue);
    });

    test('removing a profile deletes its account secrets', () {
      expect(ProfileStore.secretKeys, containsAll([AccountSessionStore.sessionKey, AccountSessionStore.dataKeyKey]));
    });
  });

  group('AccountSessionService', () {
    late _FakeSupabase server;
    late _Device phone;

    setUp(() {
      server = _FakeSupabase();
      phone = _Device(server);
    });

    test('sign-up with a code links the profile, stores session and key, never sends the password', () async {
      expect(await phone.service.status('default'), AccountStatus.local);
      await phone.createAccount('default', ' Ana@Example.com', _pw);

      final user = server.user(_email);
      expect(user.secret, await _secret.derive(_pw, _email));
      expect(server.bodies.where((b) => b.contains(_pw)), isEmpty);

      final profile = (await phone.profiles.byId('default'))!;
      expect(profile.account, AccountLink(userId: user.id, email: _email));
      final dataKey = (await phone.service.dataKey('default'))!;
      expect(await _crypto().unwrapWithPassword(server.envelope(_email), _pw), dataKey);
      expect(_subOf(await phone.service.accessToken('default')), user.id);
      expect(await phone.service.status('default'), AccountStatus.ready);
      // The session from the code check is not kept around.
      expect(server.sessions.values.where((s) => s.userId == user.id && !s.revoked).length, 1);
    });

    test('a wrong code is refused and stores nothing', () async {
      await phone.service.signUp('default', _email, _pw);
      await expectLater(
        phone.service.verifySignupCode('default', _email, '000000', _pw),
        throwsA(isA<InvalidCodeException>()),
      );
      expect(phone.storage.values.keys, isNot(contains(AccountSessionStore.sessionKey)));
      expect((await phone.profiles.byId('default'))!.isLocal, isTrue);
    });

    test('a different password at the code step is refused before any key is made', () async {
      await phone.service.signUp('default', _email, _pw);
      final code = server.user(_email).signupCode!;
      await expectLater(
        phone.service.verifySignupCode('default', _email, code, 'typo'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(server.keyRows, isEmpty);
      // Signing in later with the right password creates the key.
      expect(await phone.service.signIn('default', _email, _pw), SignInResult.ready);
      expect(server.keyRows, hasLength(1));
    });

    test('closed sign-ups are refused before the request', () async {
      server.signupsOpen = false;
      await expectLater(phone.service.signUp('default', _email, _pw), throwsA(isA<SignupsClosedException>()));
      expect(server.requests.where((r) => r.url.path == '/auth/v1/signup'), isEmpty);
      expect(await phone.service.signupsOpen(), isFalse);
    });

    test('the server error signups_closed maps to SignupsClosedException', () async {
      server.signupGateError = 'signups_closed';
      await expectLater(phone.service.signUp('default', _email, _pw), throwsA(isA<SignupsClosedException>()));
    });

    test('a generic database error while sign-ups just closed maps to SignupsClosedException', () async {
      server.signupGateError = 'Database error saving new user';
      final api = AccountAuthApi(_url, _anon, client: server.client);
      // Open when the app checks, closed by the time the trigger runs.
      server.signupsOpenAt = (read) => read == 0;
      final service = phone.service;
      await expectLater(service.signUp('default', _email, _pw), throwsA(isA<SignupsClosedException>()));
      // With sign-ups open the same error stays a server error.
      server.signupsOpenAt = null;
      await expectLater(api.signUp(_email, 'x'), throwsA(isA<AccountAuthRemoteException>()));
    });

    test('auto-confirming projects sign the profile in at sign-up', () async {
      server.autoConfirm = true;
      expect(await phone.service.signUp('default', _email, _pw), SignUpResult.signedIn);
      expect(await phone.service.status('default'), AccountStatus.ready);
    });

    test('sign-in on a second device opens the same data key', () async {
      await phone.createAccount('default', _email, _pw);
      final laptop = _Device(server);
      expect(await laptop.service.signIn('default', 'ANA@example.com', _pw), SignInResult.ready);
      expect(await laptop.service.dataKey('default'), await phone.service.dataKey('default'));
      expect(server.bodies.where((b) => b.contains(_pw)), isEmpty);
    });

    test('sign-in errors are typed', () async {
      await phone.service.signUp('default', _email, _pw);
      final laptop = _Device(server);
      await expectLater(laptop.service.signIn('default', _email, _pw), throwsA(isA<EmailNotConfirmedException>()));
      await phone.service.verifySignupCode('default', _email, server.user(_email).signupCode!, _pw);
      await expectLater(laptop.service.signIn('default', _email, 'wrong'), throwsA(isA<InvalidCredentialsException>()));
    });

    test('sign-in clears a needs_rewrap flag when the password already opens the key', () async {
      await phone.createAccount('default', _email, _pw);
      await phone.keys.markNeedsRewrap(await phone.service.accessToken('default'));
      final laptop = _Device(server);
      expect(await laptop.service.signIn('default', _email, _pw), SignInResult.ready);
      expect(server.envelope(_email).needsRewrap, isFalse);
    });

    group('password reset', () {
      test('on a device without the key flags needs_rewrap; the device with it rewraps', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = await phone.service.dataKey('default');
        final laptop = _Device(server);

        await laptop.service.requestPasswordReset(_email);
        final code = server.user(_email).recoveryCode!;
        expect(await laptop.service.completePasswordReset(_email, code, _newPw), PasswordResetResult.needsRewrap);
        expect(server.envelope(_email).needsRewrap, isTrue);
        expect(server.user(_email).secret, await _secret.derive(_newPw, _email));
        expect(server.bodies.where((b) => b.contains(_newPw)), isEmpty);

        // The new password signs in but cannot open the key there.
        expect(await laptop.service.signIn('default', _email, _newPw), SignInResult.needsRecoveryKey);
        expect(await laptop.service.status('default'), AccountStatus.local);
        expect(laptop.storage.values, isEmpty);

        // The phone notices, checks the new password and wraps again.
        expect(await phone.service.status('default'), AccountStatus.needsRewrap);
        await expectLater(
          phone.service.rewrapAfterReset('default', 'wrong'),
          throwsA(isA<InvalidCredentialsException>()),
        );
        await phone.service.rewrapAfterReset('default', _newPw);
        expect(await phone.service.status('default'), AccountStatus.ready);
        expect(server.envelope(_email).needsRewrap, isFalse);

        expect(await laptop.service.signIn('default', _email, _newPw), SignInResult.ready);
        expect(await laptop.service.dataKey('default'), dataKey);
      });

      test('on a device with the key rewraps at once', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = await phone.service.dataKey('default');

        await phone.service.requestPasswordReset(_email);
        final code = server.user(_email).recoveryCode!;
        expect(await phone.service.completePasswordReset(_email, code, _newPw), PasswordResetResult.rewrapped);
        expect(server.envelope(_email).needsRewrap, isFalse);
        expect(await _crypto().unwrapWithPassword(server.envelope(_email), _newPw), dataKey);

        final laptop = _Device(server);
        await expectLater(laptop.service.signIn('default', _email, _pw), throwsA(isA<InvalidCredentialsException>()));
        expect(await laptop.service.signIn('default', _email, _newPw), SignInResult.ready);
        expect(await laptop.service.dataKey('default'), dataKey);
        // The recovery session is revoked after use.
        expect(server.sessions.values.where((s) => !s.revoked).length, 2);
      });

      test('a wrong reset code changes nothing', () async {
        await phone.createAccount('default', _email, _pw);
        await phone.service.requestPasswordReset(_email);
        await expectLater(
          phone.service.completePasswordReset(_email, '999999', _newPw),
          throwsA(isA<InvalidCodeException>()),
        );
        expect(server.user(_email).secret, await _secret.derive(_pw, _email));
      });

      test('the recovery key opens the data key after a reset with no device holding it', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = (await phone.service.dataKey('default'))!;
        final recoveryKey = await phone.keys.setRecoveryKey(dataKey, await phone.service.accessToken('default'));
        await phone.service.signOut('default');

        final laptop = _Device(server);
        await laptop.service.requestPasswordReset(_email);
        await laptop.service.completePasswordReset(_email, server.user(_email).recoveryCode!, _newPw);
        expect(await laptop.service.signIn('default', _email, _newPw), SignInResult.needsRecoveryKey);
        await expectLater(
          laptop.service.recoverWithRecoveryKey('default', _email, _newPw, '0000-0000-0000-0000-0000-0000-0000-0000'),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
        await laptop.service.recoverWithRecoveryKey('default', _email, _newPw, recoveryKey.toLowerCase());
        expect(await laptop.service.dataKey('default'), dataKey);
        expect(server.envelope(_email).needsRewrap, isFalse);
        expect(await laptop.service.status('default'), AccountStatus.ready);
      });

      test('a profile that lost its session but kept the key rewraps on sign-in', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = await phone.service.dataKey('default');
        final laptop = _Device(server);
        await laptop.service.requestPasswordReset(_email);
        await laptop.service.completePasswordReset(_email, server.user(_email).recoveryCode!, _newPw);

        // The server drops the phone's session.
        for (final s in server.sessions.values) {
          s.revoked = true;
        }
        server.now = server.now.add(const Duration(hours: 2));
        expect(await phone.service.status('default'), AccountStatus.signedOut);
        expect(await phone.service.dataKey('default'), dataKey);

        expect(await phone.service.signIn('default', _email, _newPw), SignInResult.ready);
        expect(server.envelope(_email).needsRewrap, isFalse);
        expect(await _crypto().unwrapWithPassword(server.envelope(_email), _newPw), dataKey);
      });
    });

    group('change password', () {
      test('rewraps the key and updates the Auth secret', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = await phone.service.dataKey('default');
        await phone.service.changePassword('default', _pw, _newPw);

        expect(await _crypto().unwrapWithPassword(server.envelope(_email), _newPw), dataKey);
        expect(server.user(_email).secret, await _secret.derive(_newPw, _email));
        expect(server.bodies.where((b) => b.contains(_newPw) || b.contains(_pw)), isEmpty);
        expect(await phone.service.status('default'), AccountStatus.ready);
        final laptop = _Device(server);
        expect(await laptop.service.signIn('default', _email, _newPw), SignInResult.ready);
      });

      test('a wrong current password changes nothing', () async {
        await phone.createAccount('default', _email, _pw);
        final before = server.envelope(_email);
        await expectLater(
          phone.service.changePassword('default', 'wrong', _newPw),
          throwsA(isA<InvalidCredentialsException>()),
        );
        expect(server.envelope(_email), before);
      });

      test('rolls the wrap back when the Auth update fails', () async {
        await phone.createAccount('default', _email, _pw);
        final dataKey = await phone.service.dataKey('default');
        server.failPasswordUpdates = true;
        await expectLater(
          phone.service.changePassword('default', _pw, _newPw),
          throwsA(isA<AccountAuthRemoteException>()),
        );
        expect(await _crypto().unwrapWithPassword(server.envelope(_email), _pw), dataKey);
        await expectLater(
          _crypto().unwrapWithPassword(server.envelope(_email), _newPw),
          throwsA(isA<WrongPasswordException>()),
        );
        expect(server.user(_email).secret, await _secret.derive(_pw, _email));
        server.failPasswordUpdates = false;
        expect(await _Device(server).service.signIn('default', _email, _pw), SignInResult.ready);
      });
    });

    group('profiles and sessions', () {
      test('two profiles keep separate sessions and keys; refresh never crosses', () async {
        final work = await phone.newProfile('Work');
        await phone.createAccount('default', _email, _pw);
        await phone.createAccount(work, 'bob@example.com', 'bob password');
        final ana = server.user(_email).id;
        final bob = server.user('bob@example.com').id;

        expect(_subOf(await phone.service.accessToken('default')), ana);
        expect(_subOf(await phone.service.accessToken(work)), bob);
        expect(await phone.service.dataKey('default'), isNot(await phone.service.dataKey(work)));

        final anaBefore = (await phone.store.readSession('default'))!;
        final bobBefore = (await phone.store.readSession(work))!;
        server.now = server.now.add(const Duration(minutes: 59, seconds: 30));
        final anaToken = await phone.service.accessToken('default');
        expect(_subOf(anaToken), ana);
        expect(anaToken, isNot(anaBefore.accessToken));
        final refreshes = server.requests.where((r) => r.url.queryParameters['grant_type'] == 'refresh_token');
        expect(refreshes.map((r) => jsonDecode(r.body)['refresh_token']), [anaBefore.refreshToken]);
        expect((await phone.store.readSession(work))!.refreshToken, bobBefore.refreshToken);

        final bobToken = await phone.service.accessToken(work);
        expect(_subOf(bobToken), bob);
        expect(bobToken, isNot(anaToken));
        expect((await phone.store.readSession('default'))!.userId, ana);
        expect((await phone.store.readSession(work))!.userId, bob);
      });

      test('concurrent callers share one refresh', () async {
        await phone.createAccount('default', _email, _pw);
        server.now = server.now.add(const Duration(hours: 2));
        final tokens = await Future.wait([for (var i = 0; i < 5; i++) phone.service.accessToken('default')]);
        expect(tokens.toSet(), hasLength(1));
        expect(server.requests.where((r) => r.url.queryParameters['grant_type'] == 'refresh_token'), hasLength(1));
      });

      test('a refused refresh token signs the profile out but keeps the key', () async {
        await phone.createAccount('default', _email, _pw);
        for (final s in server.sessions.values) {
          s.revoked = true;
        }
        server.now = server.now.add(const Duration(hours: 2));
        await expectLater(phone.service.accessToken('default'), throwsA(isA<SessionExpiredException>()));
        expect(await phone.store.readSession('default'), isNull);
        expect(await phone.service.dataKey('default'), isNotNull);
        expect(await phone.service.status('default'), AccountStatus.signedOut);
        await expectLater(phone.service.accessToken('default'), throwsA(isA<NotSignedInException>()));
      });

      test('sign-out revokes and deletes the session and key of that profile only', () async {
        final work = await phone.newProfile('Work');
        await phone.createAccount('default', _email, _pw);
        await phone.createAccount(work, 'bob@example.com', 'bob password');
        final ana = (await phone.store.readSession('default'))!;
        final bobKey = await phone.service.dataKey(work);

        await phone.service.signOut('default');
        expect(server.liveRefreshToken(ana.refreshToken), isFalse);
        expect(await phone.store.readSession('default'), isNull);
        expect(await phone.service.dataKey('default'), isNull);
        expect(await phone.service.status('default'), AccountStatus.signedOut);
        // The profile and its link stay for C8 to delete after the pending check.
        expect((await phone.profiles.byId('default'))!.account?.email, _email);

        expect(await phone.service.dataKey(work), bobKey);
        expect(_subOf(await phone.service.accessToken(work)), server.user('bob@example.com').id);
        expect(await phone.service.status(work), AccountStatus.ready);
      });

      test('sign-out works offline and still forgets the session', () async {
        await phone.createAccount('default', _email, _pw);
        final offline = AccountSessionService(
          api: AccountAuthApi(_url, _anon, client: MockClient((_) async => throw http.ClientException('offline'))),
          keys: phone.keys,
          store: phone.store,
          profiles: phone.profiles,
          secret: _secret,
          now: () => server.now,
        );
        await offline.signOut('default');
        expect(await phone.store.readSession('default'), isNull);
        expect(await phone.service.dataKey('default'), isNull);
      });

      test('status trusts the local state when the server is unreachable', () async {
        await phone.createAccount('default', _email, _pw);
        final offline = AccountSessionService(
          api: AccountAuthApi(_url, _anon, client: server.client),
          keys: AccountKeyService(
            AccountKeyRemote(_url, _anon, client: MockClient((_) async => throw http.ClientException('offline'))),
            crypto: _crypto(),
          ),
          store: phone.store,
          profiles: phone.profiles,
          secret: _secret,
          now: () => server.now,
        );
        expect(await offline.status('default'), AccountStatus.ready);
      });

      test('an account already on another profile is refused', () async {
        final work = await phone.newProfile('Work');
        await phone.createAccount('default', _email, _pw);
        final sessionsBefore = server.sessions.length;
        await expectLater(
          phone.service.signIn(work, 'ANA@example.com', _pw),
          throwsA(isA<AccountAlreadyOnDeviceException>().having((e) => e.profileId, 'profileId', 'default')),
        );
        await expectLater(phone.service.signUp(work, _email, _pw), throwsA(isA<AccountAlreadyOnDeviceException>()));
        expect(server.sessions.length, sessionsBefore);
        expect((await phone.profiles.byId(work))!.isLocal, isTrue);
      });

      test('an account whose email changed is still caught by user id', () async {
        final work = await phone.newProfile('Work');
        await phone.createAccount('default', _email, _pw);
        // The link holds an older address for the same user.
        final link = (await phone.profiles.byId('default'))!.account!;
        await phone.profiles.setAccount('default', AccountLink(userId: link.userId, email: 'old@example.com'));
        await expectLater(phone.service.signIn(work, _email, _pw), throwsA(isA<AccountAlreadyOnDeviceException>()));
        expect(server.sessions.values.where((s) => !s.revoked).length, 1);
      });

      test('a profile linked to one account refuses another', () async {
        await phone.createAccount('default', _email, _pw);
        final other = _Device(server);
        await other.createAccount('default', 'bob@example.com', 'bob password');
        await phone.service.signOut('default');
        await expectLater(
          phone.service.signIn('default', 'bob@example.com', 'bob password'),
          throwsA(isA<ProfileHasOtherAccountException>()),
        );
        // The same account is welcome back.
        expect(await phone.service.signIn('default', _email, _pw), SignInResult.ready);
      });

      test('a local profile with data is attached in place', () async {
        final work = await phone.newProfile('Work');
        await phone.createAccount(work, _email, _pw);
        final profile = (await phone.profiles.byId(work))!;
        expect(profile.name, 'Work');
        expect(profile.account?.userId, server.user(_email).id);
        expect((await phone.profiles.byId('default'))!.isLocal, isTrue);
        expect(await phone.service.status('default'), AccountStatus.local);
        // Secrets use the profile's suffix.
        expect(phone.storage.values.keys, containsAll(['AccountSession.$work', 'AccountDataKey.$work']));
      });
    });
  });
}
