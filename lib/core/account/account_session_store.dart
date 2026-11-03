import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:opennutritracker/core/account/account_auth_api.dart';
import 'package:opennutritracker/core/account/account_key_crypto.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// Per-profile account secrets in secure storage, next to the Hive key and
/// the sync key: the Auth session (refresh token) and the unwrapped data
/// key, so the app opens without asking for the password. Keys follow
/// [ProfileScope.secretFor], so every profile has its own and they are
/// deleted with the profile ([ProfileStore.secretKeys]).
class AccountSessionStore {
  static const sessionKey = 'AccountSession';
  static const dataKeyKey = 'AccountDataKey';

  final FlutterSecureStorage _storage;

  AccountSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  Future<AuthSession?> readSession(String profileId) async {
    final raw = await _storage.read(key: ProfileScope.secretFor(sessionKey, profileId));
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> writeSession(String profileId, AuthSession session) =>
      _storage.write(key: ProfileScope.secretFor(sessionKey, profileId), value: jsonEncode(session.toJson()));

  Future<void> deleteSession(String profileId) => _storage.delete(key: ProfileScope.secretFor(sessionKey, profileId));

  /// The data key of [userId] stored for [profileId], or null when there is
  /// none or it belongs to another user.
  Future<Uint8List?> readDataKey(String profileId, String userId) async {
    final raw = await _storage.read(key: ProfileScope.secretFor(dataKeyKey, profileId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['user'] != userId) return null;
      final key = base64Url.decode(json['key'] as String);
      return key.length == AccountKeyCrypto.dataKeyLength ? key : null;
    } on Object {
      return null;
    }
  }

  Future<void> writeDataKey(String profileId, String userId, Uint8List key) => _storage.write(
    key: ProfileScope.secretFor(dataKeyKey, profileId),
    value: jsonEncode({'user': userId, 'key': base64Url.encode(key)}),
  );

  Future<void> deleteDataKey(String profileId) => _storage.delete(key: ProfileScope.secretFor(dataKeyKey, profileId));
}
