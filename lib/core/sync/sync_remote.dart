import 'dart:convert';

import 'package:http/http.dart' as http;

/// One row of `public.sync_records` (docs/desktop/sync_records.sql).
class SyncRow {
  final String box;
  final String id;

  /// Encrypted record; null for a deletion.
  final String? payload;
  final DateTime modifiedAt;

  /// Server clock; only set on rows read back from the server.
  final DateTime? updatedAt;
  final bool deleted;

  const SyncRow({
    required this.box,
    required this.id,
    required this.payload,
    required this.modifiedAt,
    this.updatedAt,
    this.deleted = false,
  });

  factory SyncRow.fromJson(Map<String, dynamic> json) => SyncRow(
    box: json['box'] as String,
    id: json['id'] as String,
    payload: json['payload'] as String?,
    modifiedAt: DateTime.parse(json['modified_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    deleted: json['deleted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson(String token) => {
    'token': token,
    'box': box,
    'id': id,
    'payload': payload,
    'modified_at': modifiedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };
}

/// The server side of sync, kept behind an interface so the engine can be
/// tested against an in-memory fake.
abstract class SyncRemote {
  /// Rows with `updated_at` after [since] (all rows when null), oldest
  /// first, at most [limit].
  Future<List<SyncRow>> pull(String token, DateTime? since, {int limit});

  /// Upserts [rows]; the server keeps whichever version has the newer
  /// `modified_at`.
  Future<void> push(String token, List<SyncRow> rows);
}

class SyncRemoteException implements Exception {
  final int statusCode;
  final String body;

  const SyncRemoteException(this.statusCode, this.body);

  @override
  String toString() => 'SyncRemoteException($statusCode): $body';
}

/// PostgREST client for the backup Supabase project. Plain HTTP rather than
/// the Supabase SDK so the per-request `x-sync-token` header the RLS policies
/// read is explicit.
class SupabaseSyncRemote implements SyncRemote {
  final String baseUrl;
  final String anonKey;
  final http.Client _client;

  SupabaseSyncRemote(this.baseUrl, this.anonKey, {http.Client? client}) : _client = client ?? http.Client();

  Uri get _endpoint => Uri.parse('$baseUrl/rest/v1/sync_records');

  Map<String, String> _headers(String token) => {
    'apikey': anonKey,
    'x-sync-token': token,
    'Content-Type': 'application/json',
  };

  @override
  Future<List<SyncRow>> pull(String token, DateTime? since, {int limit = 500}) async {
    final query = <String, String>{
      'select': 'box,id,payload,modified_at,updated_at,deleted',
      'order': 'updated_at.asc',
      'limit': '$limit',
      if (since != null) 'updated_at': 'gt.${since.toUtc().toIso8601String()}',
    };
    final response = await _client.get(_endpoint.replace(queryParameters: query), headers: _headers(token));
    if (response.statusCode != 200) {
      throw SyncRemoteException(response.statusCode, response.body);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.map((r) => SyncRow.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> push(String token, List<SyncRow> rows) async {
    if (rows.isEmpty) return;
    final response = await _client.post(
      _endpoint.replace(queryParameters: {'on_conflict': 'token,box,id'}),
      headers: {..._headers(token), 'Prefer': 'resolution=merge-duplicates,return=minimal'},
      body: jsonEncode(rows.map((r) => r.toJson(token)).toList()),
    );
    if (response.statusCode != 201 && response.statusCode != 200 && response.statusCode != 204) {
      throw SyncRemoteException(response.statusCode, response.body);
    }
  }
}
