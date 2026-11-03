import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One synced row: `public.account_records` for accounts, the token table
/// `public.sync_records` (docs/desktop/sync_records.sql) for old pairings.
class SyncRow {
  final String box;
  final String id;

  /// Encrypted record; null for a deletion.
  final String? payload;
  final DateTime modifiedAt;

  /// Server clock; only set on rows read back from the server.
  final DateTime? updatedAt;

  /// [updatedAt] exactly as the server sent it (microseconds, which a
  /// browser's [DateTime] drops), for the next page's keyset filter.
  final String? updatedAtRaw;
  final bool deleted;

  const SyncRow({
    required this.box,
    required this.id,
    required this.payload,
    required this.modifiedAt,
    this.updatedAt,
    this.updatedAtRaw,
    this.deleted = false,
  });

  factory SyncRow.fromJson(Map<String, dynamic> json) => SyncRow(
    box: json['box'] as String,
    id: json['id'] as String,
    payload: json['payload'] as String?,
    modifiedAt: DateTime.parse(json['modified_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    updatedAtRaw: json['updated_at'] as String,
    deleted: json['deleted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'box': box,
    'id': id,
    'payload': payload,
    'modified_at': modifiedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };
}

/// The server side of sync for one set of rows (one account, or one old
/// pairing token), kept behind an interface so the engine can be tested
/// against an in-memory fake. Each instance carries its own credential.
abstract class SyncRemote {
  /// Rows ordered by (`updated_at`, `box`, `id`), at most [limit]. The first
  /// page passes [since] (all rows when null): rows with `updated_at` after
  /// it. Following pages pass the last row read as [after], so rows that
  /// share one `updated_at` (a pushed batch) are never skipped at a page
  /// boundary.
  Future<List<SyncRow>> pull({DateTime? since, SyncRow? after, int limit});

  /// Upserts [rows]; the server keeps whichever version has the newer
  /// `modified_at`.
  Future<void> push(List<SyncRow> rows);

  /// The row ([box], [id]), or null.
  Future<SyncRow?> fetch(String box, String id);

  /// Deletes every row of this set.
  Future<void> deleteAll();
}

class SyncRemoteException implements Exception {
  final int statusCode;
  final String body;

  const SyncRemoteException(this.statusCode, this.body);

  @override
  String toString() => 'SyncRemoteException($statusCode): $body';
}

/// Shared PostgREST plumbing of the two tables. Plain HTTP rather than the
/// Supabase SDK so the credential of every request is explicit.
abstract class _PostgrestSyncRemote implements SyncRemote {
  static const _columns = 'box,id,payload,modified_at,updated_at,deleted';
  static const _timeout = Duration(seconds: 30);

  final String baseUrl;
  final String anonKey;
  final http.Client client;

  _PostgrestSyncRemote(String projectUrl, this.anonKey, http.Client? client)
    : baseUrl = projectUrl.replaceAll(RegExp(r'/+$'), ''),
      client = client ?? http.Client();

  String get table;

  /// Columns of the primary key, for `on_conflict`.
  String get conflictColumns;

  /// Filter that names this set's rows in a DELETE (RLS limits it anyway).
  Future<Map<String, String>> get ownRowsFilter;

  Future<Map<String, dynamic>> rowJson(SyncRow row);

  /// Sends one request with this set's credential.
  Future<http.Response> send(Future<http.Response> Function(Map<String, String> headers) request);

  Uri get _endpoint => Uri.parse('$baseUrl/rest/v1/$table');

  Map<String, String> baseHeaders() => {'apikey': anonKey, 'Content-Type': 'application/json'};

  Future<http.Response> _timed(Future<http.Response> response) => response.timeout(_timeout);

  static String _quote(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  @override
  Future<List<SyncRow>> pull({DateTime? since, SyncRow? after, int limit = 500}) async {
    final query = <String, String>{'select': _columns, 'order': 'updated_at.asc,box.asc,id.asc', 'limit': '$limit'};
    if (after != null) {
      final at = _quote(after.updatedAtRaw ?? after.updatedAt!.toUtc().toIso8601String());
      final box = _quote(after.box);
      final id = _quote(after.id);
      query['or'] =
          '(updated_at.gt.$at,and(updated_at.eq.$at,box.gt.$box),and(updated_at.eq.$at,box.eq.$box,id.gt.$id))';
    } else if (since != null) {
      query['updated_at'] = 'gt.${since.toUtc().toIso8601String()}';
    }
    final response = await send((h) => _timed(client.get(_endpoint.replace(queryParameters: query), headers: h)));
    if (response.statusCode != 200) throw SyncRemoteException(response.statusCode, response.body);
    final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return rows.map((r) => SyncRow.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> push(List<SyncRow> rows) async {
    if (rows.isEmpty) return;
    final body = jsonEncode([for (final r in rows) await rowJson(r)]);
    final response = await send(
      (h) => _timed(
        client.post(
          _endpoint.replace(queryParameters: {'on_conflict': conflictColumns}),
          headers: {...h, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
          body: body,
        ),
      ),
    );
    if (response.statusCode != 201 && response.statusCode != 200 && response.statusCode != 204) {
      throw SyncRemoteException(response.statusCode, response.body);
    }
  }

  @override
  Future<SyncRow?> fetch(String box, String id) async {
    final query = {'select': _columns, 'box': 'eq.$box', 'id': 'eq.$id'};
    final response = await send((h) => _timed(client.get(_endpoint.replace(queryParameters: query), headers: h)));
    if (response.statusCode != 200) throw SyncRemoteException(response.statusCode, response.body);
    final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return rows.isEmpty ? null : SyncRow.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAll() async {
    final filter = await ownRowsFilter;
    final response = await send(
      (h) => _timed(
        client.delete(_endpoint.replace(queryParameters: filter), headers: {...h, 'Prefer': 'return=minimal'}),
      ),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw SyncRemoteException(response.statusCode, response.body);
    }
  }
}

/// The old pairing-token table `public.sync_records`: no login, the token in
/// the `x-sync-token` header is the credential checked by RLS. Only used for
/// profiles that still have a pairing and no account, and to retire that
/// pairing once the account holds the data (removed in task D11).
class TokenSyncRemote extends _PostgrestSyncRemote {
  final String token;

  TokenSyncRemote(String projectUrl, String anonKey, this.token, {http.Client? client})
    : super(projectUrl, anonKey, client);

  @override
  String get table => 'sync_records';

  @override
  String get conflictColumns => 'token,box,id';

  @override
  Future<Map<String, String>> get ownRowsFilter async => {'token': 'eq.$token'};

  @override
  Future<Map<String, dynamic>> rowJson(SyncRow row) async => {'token': token, ...row.toJson()};

  @override
  Future<http.Response> send(Future<http.Response> Function(Map<String, String> headers) request) =>
      request({...baseHeaders(), 'x-sync-token': token});
}

/// The account was signed in as another user than the profile's link.
class AccountTokenMismatchException implements Exception {
  const AccountTokenMismatchException();

  @override
  String toString() => 'AccountTokenMismatchException: the access token belongs to another account';
}

/// `public.account_records` of one account (docs/plan-cuentas.md, task B6).
/// Every request carries `Authorization: Bearer <access token>`; RLS limits
/// it to the rows of that user. The token comes from [accessToken] right
/// before each request, so no request is ever sent without one: when it
/// throws (signed out, session expired) nothing goes out. A 401 asks for a
/// refreshed token once and retries; a second 401 is reported as a
/// [SyncRemoteException].
class AccountSyncRemote extends _PostgrestSyncRemote {
  /// The Supabase Auth user the rows belong to; a token for anyone else is
  /// refused before sending.
  final String userId;
  final Future<String> Function({bool forceRefresh}) accessToken;

  AccountSyncRemote(String projectUrl, String anonKey, this.userId, this.accessToken, {http.Client? client})
    : super(projectUrl, anonKey, client);

  @override
  String get table => 'account_records';

  @override
  String get conflictColumns => 'user_id,box,id';

  @override
  Future<Map<String, String>> get ownRowsFilter async => {'user_id': 'eq.$userId'};

  @override
  Future<Map<String, dynamic>> rowJson(SyncRow row) async => {'user_id': userId, ...row.toJson()};

  @override
  Future<http.Response> send(Future<http.Response> Function(Map<String, String> headers) request) async {
    var response = await request(await _headers(forceRefresh: false));
    if (response.statusCode == 401) response = await request(await _headers(forceRefresh: true));
    return response;
  }

  Future<Map<String, String>> _headers({required bool forceRefresh}) async {
    final token = await accessToken(forceRefresh: forceRefresh);
    if (token.isEmpty) throw const AccountTokenMismatchException();
    if (subjectOf(token) != userId) throw const AccountTokenMismatchException();
    return {...baseHeaders(), 'Authorization': 'Bearer $token'};
  }

  /// The `sub` claim of a JWT, or null. Only a guard against sending one
  /// profile's rows with another account's token; the server verifies the
  /// signature.
  static String? subjectOf(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final sub = claims is Map<String, dynamic> ? claims['sub'] : null;
      return sub is String ? sub : null;
    } on Object {
      return null;
    }
  }
}
