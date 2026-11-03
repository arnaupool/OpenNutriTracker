import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:opennutritracker/core/account/account_session_exceptions.dart';

/// One Supabase Auth session: what a profile keeps in secure storage.
class AuthSession {
  final String accessToken;
  final String refreshToken;

  /// When [accessToken] expires, UTC.
  final DateTime expiresAt;
  final String userId;
  final String email;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
  });

  bool expiresWithin(Duration margin, DateTime now) => !now.add(margin).isBefore(expiresAt);

  /// Reads a GoTrue session answer (`/token`, `/verify`, `/signup` with
  /// auto-confirm). Throws [FormatException] when a field is missing.
  factory AuthSession.fromGoTrue(Map<String, dynamic> json, DateTime now) {
    final user = json['user'];
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    if (access is! String || refresh is! String || user is! Map<String, dynamic>) {
      throw const FormatException('not a session');
    }
    final id = user['id'];
    if (id is! String || id.isEmpty) throw const FormatException('session without user id');
    final expiresAtSeconds = json['expires_at'];
    final expiresIn = json['expires_in'];
    final DateTime expiresAt;
    if (expiresAtSeconds is int) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000, isUtc: true);
    } else if (expiresIn is int) {
      expiresAt = now.toUtc().add(Duration(seconds: expiresIn));
    } else {
      throw const FormatException('session without expiry');
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
      userId: id,
      email: (user['email'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'user_id': userId,
    'email': email,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch((json['expires_at'] as int) * 1000, isUtc: true),
    userId: json['user_id'] as String,
    email: json['email'] as String,
  );

  /// Never prints tokens.
  @override
  String toString() => 'AuthSession(user: $userId, expiresAt: $expiresAt)';
}

/// Supabase Auth (GoTrue) REST API and the anon `app_settings` read, over
/// plain HTTP. Stateless: each call takes the tokens it needs, so one
/// instance serves every profile and no session is shared between them.
///
/// The `password` argument of every method is the Auth secret from
/// `AccountAuthSecret`, never what the user typed.
class AccountAuthApi {
  static const _timeout = Duration(seconds: 20);

  final String baseUrl;
  final String anonKey;
  final http.Client _client;
  final DateTime Function() _now;

  AccountAuthApi(String projectUrl, this.anonKey, {http.Client? client, DateTime Function()? now})
    : baseUrl = projectUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  /// `public.app_settings.signups_open`, readable by anon.
  Future<bool> signupsOpen() async {
    final uri = Uri.parse('$baseUrl/rest/v1/app_settings').replace(queryParameters: {'select': 'signups_open'});
    final response = await _send(() => _client.get(uri, headers: _headers()));
    if (response.statusCode != 200) throw _error(response);
    final rows = _decode(response);
    if (rows is! List<dynamic> || rows.isEmpty) return true;
    final open = (rows.first as Map<String, dynamic>)['signups_open'];
    return open is! bool || open;
  }

  /// Registers the account. Returns null when the server sends a 6-digit
  /// confirmation code (the normal case), or the session when the project
  /// confirms emails automatically.
  Future<AuthSession?> signUp(String email, String password) async {
    final json = await _postJson('/auth/v1/signup', {'email': email, 'password': password});
    return json is Map<String, dynamic> && json['access_token'] is String ? AuthSession.fromGoTrue(json, _now()) : null;
  }

  Future<void> resendSignupCode(String email) => _postJson('/auth/v1/resend', {'type': 'signup', 'email': email});

  Future<AuthSession> signIn(String email, String password) async =>
      _session(await _postJson('/auth/v1/token?grant_type=password', {'email': email, 'password': password}));

  /// Checks a 6-digit code. [type] is `signup` or `recovery`.
  Future<AuthSession> verifyOtp(String email, String code, String type) async =>
      _session(await _postJson('/auth/v1/verify', {'type': type, 'email': email, 'token': code.trim()}));

  /// Exchanges the refresh token for a new session. Throws
  /// [SessionExpiredException] when the server no longer accepts it.
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      return _session(await _postJson('/auth/v1/token?grant_type=refresh_token', {'refresh_token': refreshToken}));
    } on AccountAuthRemoteException catch (e) {
      if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 429) throw const SessionExpiredException();
      rethrow;
    } on InvalidCredentialsException {
      throw const SessionExpiredException();
    }
  }

  /// Sends the password-reset email (its template carries `{{ .Token }}`).
  Future<void> requestPasswordReset(String email) => _postJson('/auth/v1/recover', {'email': email});

  /// Sets the Auth password of the user in [accessToken]. Setting the same
  /// password again counts as success.
  Future<void> updatePassword(String accessToken, String password) async {
    final response = await _send(
      () => _client.put(
        Uri.parse('$baseUrl/auth/v1/user'),
        headers: _headers(accessToken),
        body: jsonEncode({'password': password}),
      ),
    );
    if (response.statusCode == 200) return;
    if (_errorCode(response) == 'same_password') return;
    throw _error(response);
  }

  /// Revokes the session of [accessToken] (only that one, `scope=local`).
  Future<void> signOut(String accessToken) async {
    final response = await _send(
      () => _client.post(Uri.parse('$baseUrl/auth/v1/logout?scope=local'), headers: _headers(accessToken)),
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    // Already gone on the server: nothing left to revoke.
    if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404) return;
    throw _error(response);
  }

  /// Anonymous calls send only `apikey`, like `SupabaseSyncRemote`.
  Map<String, String> _headers([String? accessToken]) => {
    'apikey': anonKey,
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Object?> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _send(
      () => _client.post(Uri.parse('$baseUrl$path'), headers: _headers(), body: jsonEncode(body)),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw _error(response);
    return _decode(response);
  }

  AuthSession _session(Object? json) {
    try {
      return AuthSession.fromGoTrue(json as Map<String, dynamic>, _now());
    } on Object catch (e) {
      throw AccountAuthRemoteException(200, null, 'bad session answer: $e');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on http.ClientException catch (e) {
      throw AccountNetworkException(e);
    } on TimeoutException catch (e) {
      throw AccountNetworkException(e);
    }
  }

  static Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AccountAuthRemoteException(response.statusCode, null, 'not JSON');
    }
  }

  static Map<String, dynamic> _errorJson(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? json : const {};
    } on Object {
      return const {};
    }
  }

  /// GoTrue's machine-readable code: `error_code` on current servers,
  /// `error` on the older token endpoint.
  static String? _errorCode(http.Response response) {
    final json = _errorJson(response);
    final code = json['error_code'] ?? json['error'];
    return code is String ? code : null;
  }

  /// Maps a GoTrue or PostgREST error to a typed exception.
  static AccountSessionException _error(http.Response response) {
    final json = _errorJson(response);
    final code = _errorCode(response);
    final detail = '${json['msg'] ?? json['message'] ?? json['error_description'] ?? ''}';
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.contains('signups_closed') || code == 'signup_disabled') return const SignupsClosedException();
    if (code == 'invalid_credentials' || (code == 'invalid_grant' && detail.contains('credentials'))) {
      return const InvalidCredentialsException();
    }
    if (code == 'email_not_confirmed' || detail.contains('Email not confirmed')) {
      return const EmailNotConfirmedException();
    }
    if (code == 'otp_expired' || code == 'otp_disabled' || detail.contains('Token has expired or is invalid')) {
      return const InvalidCodeException();
    }
    if (response.statusCode == 429 || (code != null && code.startsWith('over_') && code.endsWith('rate_limit'))) {
      return const AuthRateLimitedException();
    }
    return AccountAuthRemoteException(response.statusCode, code, detail.isEmpty ? 'no detail' : detail);
  }
}
