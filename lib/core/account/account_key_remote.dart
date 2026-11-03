import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:opennutritracker/core/account/account_key_envelope.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';

/// PostgREST client for the caller's own `public.account_keys` row. Plain
/// HTTP like `SupabaseSyncRemote`; RLS (`user_id = auth.uid()`) limits every
/// request to the row of the user in the access token.
///
/// There is no upsert on purpose: overwriting an existing row would replace
/// the data key and orphan everything encrypted under it, so [insert] fails
/// with [AccountKeyConflictException] instead and every later change goes
/// through [patch].
class AccountKeyRemote {
  static const _columns = 'kdf,iterations,salt,wrapped_key,recovery_salt,recovery_wrapped_key,needs_rewrap,version';
  static const _timeout = Duration(seconds: 20);

  final String baseUrl;
  final String anonKey;
  final http.Client _client;

  /// [projectUrl] is the Supabase project URL; `/rest/v1/account_keys` is
  /// added here.
  AccountKeyRemote(String projectUrl, this.anonKey, {http.Client? client})
    : baseUrl = projectUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  Uri get _endpoint => Uri.parse('$baseUrl/rest/v1/account_keys');

  Map<String, String> _headers(String accessToken) => {
    'apikey': anonKey,
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// The caller's row, or null when the account has none yet.
  Future<AccountKeyEnvelope?> fetch(String accessToken) async {
    final response = await _client
        .get(_endpoint.replace(queryParameters: {'select': _columns}), headers: _headers(accessToken))
        .timeout(_timeout);
    if (response.statusCode != 200) throw AccountKeyRemoteException(response.statusCode, response.body);
    final rows = _decodeRows(response);
    if (rows.isEmpty) return null;
    if (rows.length > 1) throw AccountKeyRemoteException(response.statusCode, 'expected one row, got ${rows.length}');
    return _envelope(rows.single);
  }

  /// Creates the caller's row. `user_id` is filled by the server from the
  /// token. Throws [AccountKeyConflictException] when a row already exists.
  Future<void> insert(AccountKeyEnvelope envelope, String accessToken) async {
    final response = await _client
        .post(
          _endpoint,
          headers: {..._headers(accessToken), 'Prefer': 'return=minimal'},
          body: jsonEncode(envelope.toJson()),
        )
        .timeout(_timeout);
    if (response.statusCode == 409) throw const AccountKeyConflictException();
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AccountKeyRemoteException(response.statusCode, response.body);
    }
  }

  /// Updates [fields] of the caller's row and returns the row as stored.
  /// Throws [AccountKeyNotFoundException] when nothing was updated, so a
  /// caller never assumes a write that did not happen (a password change
  /// must not go ahead if the rewrap was not saved).
  Future<AccountKeyEnvelope> patch(Map<String, dynamic> fields, String accessToken) async {
    final query = {'user_id': 'eq.${_userId(accessToken)}', 'select': _columns};
    final response = await _client
        .patch(
          _endpoint.replace(queryParameters: query),
          headers: {..._headers(accessToken), 'Prefer': 'return=representation'},
          body: jsonEncode(fields),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) throw AccountKeyRemoteException(response.statusCode, response.body);
    final rows = _decodeRows(response);
    if (rows.isEmpty) throw const AccountKeyNotFoundException();
    if (rows.length > 1) throw AccountKeyRemoteException(response.statusCode, 'expected one row, got ${rows.length}');
    return _envelope(rows.single);
  }

  /// Deletes the caller's row ("start from scratch"). Succeeds when there
  /// is none.
  Future<void> delete(String accessToken) async {
    final response = await _client
        .delete(
          _endpoint.replace(queryParameters: {'user_id': 'eq.${_userId(accessToken)}'}),
          headers: {..._headers(accessToken), 'Prefer': 'return=minimal'},
        )
        .timeout(_timeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw AccountKeyRemoteException(response.statusCode, response.body);
    }
  }

  static List<dynamic> _decodeRows(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List<dynamic>) throw AccountKeyRemoteException(response.statusCode, 'expected a JSON array');
    return decoded;
  }

  static AccountKeyEnvelope _envelope(Object? row) {
    try {
      return AccountKeyEnvelope.fromJson(row as Map<String, dynamic>);
    } on Object catch (e) {
      throw InvalidEnvelopeException('bad account_keys row: $e');
    }
  }

  /// The `sub` claim of the access token, used only to name the row in the
  /// PATCH filter (PostgREST setups that refuse unfiltered updates). The
  /// server verifies the token and RLS still applies.
  static String _userId(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) throw ArgumentError.value('<redacted>', 'accessToken', 'not a JWT');
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final sub = (claims as Map<String, dynamic>)['sub'];
      if (sub is String && sub.isNotEmpty) return sub;
    } on Object {
      // Falls through to the error below.
    }
    throw ArgumentError.value('<redacted>', 'accessToken', 'has no sub claim');
  }
}
