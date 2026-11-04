import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/sync/sync_remote.dart';

/// A photo service request that did not succeed.
class PhotoRemoteException implements Exception {
  final int statusCode;

  const PhotoRemoteException(this.statusCode);

  @override
  String toString() => 'PhotoRemoteException: HTTP $statusCode';
}

/// The account photo store (photos-service/, behind the web image's nginx).
abstract class PhotoRemote {
  /// photo id → etag of every photo the account holds.
  Future<Map<String, String>> list();

  /// Stores [blob] as [photoId], replacing any previous one; returns its
  /// new etag.
  Future<String> put(String photoId, Uint8List blob);

  /// The blob of [photoId], or null when the account has none.
  Future<Uint8List?> get(String photoId);

  /// Removes [photoId]; succeeds when it was already gone.
  Future<void> delete(String photoId);
}

/// Where the photo service lives for this build: the same origin as the web
/// app (`<origin>/photos-api/v1/`). Native builds have no origin and no
/// setting for the server yet, so they return null and do not sync photos.
Uri? photoServiceBaseUri({Uri? base}) {
  if (!kIsWeb && base == null) return null;
  final origin = base ?? Uri.base;
  if (origin.scheme != 'https' && origin.scheme != 'http') return null;
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: origin.hasPort ? origin.port : null,
    path: '/photos-api/v1/',
  );
}

/// [PhotoRemote] over HTTP with the account's access token, which comes
/// from [accessToken] right before each request; a token for another user
/// than [userId] is refused before sending. A 401 asks for a refreshed token
/// once and retries.
class HttpPhotoRemote implements PhotoRemote {
  static const Duration _timeout = Duration(seconds: 60);
  static final RegExp _photoId = RegExp(r'^[0-9a-f]{64}$');

  final Uri baseUri;
  final String userId;
  final Future<String> Function({bool forceRefresh}) accessToken;
  final http.Client _client;

  HttpPhotoRemote(this.baseUri, this.userId, this.accessToken, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<Map<String, String>> list() async {
    final response = await _send((h) => _client.get(baseUri, headers: h));
    if (response.statusCode != 200) throw PhotoRemoteException(response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final photos = json is Map<String, dynamic> ? json['photos'] : null;
    if (photos is! Map<String, dynamic>) throw const FormatException('photo list without "photos"');
    return {
      for (final e in photos.entries)
        if (_photoId.hasMatch(e.key) && e.value is String) e.key: e.value as String,
    };
  }

  @override
  Future<String> put(String photoId, Uint8List blob) async {
    final response = await _send(
      (h) => _client.put(_uri(photoId), headers: {...h, 'Content-Type': 'application/octet-stream'}, body: blob),
    );
    if (response.statusCode != 200) throw PhotoRemoteException(response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final etag = json is Map<String, dynamic> ? json['etag'] : null;
    if (etag is! String || etag.isEmpty) throw const FormatException('upload answer without "etag"');
    return etag;
  }

  @override
  Future<Uint8List?> get(String photoId) async {
    final response = await _send((h) => _client.get(_uri(photoId), headers: h));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw PhotoRemoteException(response.statusCode);
    return response.bodyBytes;
  }

  @override
  Future<void> delete(String photoId) async {
    final response = await _send((h) => _client.delete(_uri(photoId), headers: h));
    if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 404) {
      throw PhotoRemoteException(response.statusCode);
    }
  }

  Uri _uri(String photoId) {
    if (!_photoId.hasMatch(photoId)) throw ArgumentError.value(photoId, 'photoId', 'must be 64 lowercase hex');
    return baseUri.resolve(photoId);
  }

  Future<http.Response> _send(Future<http.Response> Function(Map<String, String> headers) request) async {
    var response = await request(await _headers(forceRefresh: false)).timeout(_timeout);
    if (response.statusCode == 401) {
      response = await request(await _headers(forceRefresh: true)).timeout(_timeout);
    }
    return response;
  }

  Future<Map<String, String>> _headers({required bool forceRefresh}) async {
    final token = await accessToken(forceRefresh: forceRefresh);
    if (token.isEmpty || AccountSyncRemote.subjectOf(token) != userId) {
      throw const AccountTokenMismatchException();
    }
    return {'Authorization': 'Bearer $token'};
  }
}
