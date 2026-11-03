import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed admin or account-deletion call (not a network problem).
class AccountRemoteActionException implements Exception {
  final int statusCode;
  final String detail;

  const AccountRemoteActionException(this.statusCode, this.detail);

  @override
  String toString() => 'AccountRemoteActionException(HTTP $statusCode: $detail)';
}

/// Calls that need the account's bearer token and are not Auth or key
/// calls: the admin panel (C9) and "delete account" (C8). Plain HTTP like
/// the other account clients; RLS and the Edge Function enforce who may do
/// what.
class AccountAdminApi {
  static const _timeout = Duration(seconds: 20);

  final String baseUrl;
  final String anonKey;
  final http.Client _client;

  AccountAdminApi(String projectUrl, this.anonKey, {http.Client? client})
    : baseUrl = projectUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  Map<String, String> _headers(String accessToken) => {
    'apikey': anonKey,
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// `rpc/is_admin`: true when the signed-in account is an administrator.
  Future<bool> isAdmin(String accessToken) async {
    final response = await _client
        .post(Uri.parse('$baseUrl/rest/v1/rpc/is_admin'), headers: _headers(accessToken), body: '{}')
        .timeout(_timeout);
    if (response.statusCode != 200) throw _failure(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) == true;
  }

  /// `app_settings.signups_open` (readable by anyone).
  Future<bool> signupsOpen(String accessToken) async {
    final uri = Uri.parse('$baseUrl/rest/v1/app_settings').replace(queryParameters: {'select': 'signups_open'});
    final response = await _client.get(uri, headers: _headers(accessToken)).timeout(_timeout);
    if (response.statusCode != 200) throw _failure(response);
    final rows = jsonDecode(utf8.decode(response.bodyBytes));
    if (rows is! List || rows.isEmpty) return true;
    return (rows.first as Map<String, dynamic>)['signups_open'] != false;
  }

  /// Opens or closes sign-ups (`app_settings` row `id = true`). Throws when
  /// the server refuses or updates no row (the caller is not an admin).
  Future<void> setSignupsOpen(String accessToken, bool open) async {
    final uri = Uri.parse('$baseUrl/rest/v1/app_settings').replace(queryParameters: {'id': 'eq.true'});
    final response = await _client
        .patch(
          uri,
          headers: {..._headers(accessToken), 'Prefer': 'return=representation'},
          body: jsonEncode({'signups_open': open}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw _failure(response);
    final rows = jsonDecode(utf8.decode(response.bodyBytes));
    if (rows is! List || rows.isEmpty) throw AccountRemoteActionException(response.statusCode, 'no row updated');
  }

  /// `functions/v1/account-delete`: deletes the caller's account and cloud
  /// data (docs/reminders-backend.md).
  Future<void> deleteAccount(String accessToken) async {
    final response = await _client
        .post(Uri.parse('$baseUrl/functions/v1/account-delete'), headers: _headers(accessToken))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) throw _failure(response);
  }

  static AccountRemoteActionException _failure(http.Response response) =>
      AccountRemoteActionException(response.statusCode, utf8.decode(response.bodyBytes, allowMalformed: true));
}
