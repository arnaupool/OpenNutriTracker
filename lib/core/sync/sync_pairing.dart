import 'dart:convert';
import 'dart:typed_data';

import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// What a pairing code carries: the 256-bit token that scopes server rows
/// (shared with cloud backup) and, for sync, the AES key.
class SyncPairing {
  /// Prefix of a sync pairing code: `ontsync1:<token>.<base64url key>`.
  static const String prefix = 'ontsync1:';

  final String token;
  final Uint8List key;

  const SyncPairing(this.token, this.key);

  String encode() => '$prefix$token.${base64Url.encode(key)}';

  /// Whitespace and invisible characters that chat apps, mail clients and
  /// soft line wrapping slip into a pasted code. None can be part of a code.
  static final RegExp _noise = RegExp(r'[\s ​-‍⁠﻿]');

  static final RegExp _code = RegExp(r'ontsync1:([a-fA-F0-9]{64})\.([A-Za-z0-9_\-]+)=*', caseSensitive: false);

  /// Parses a code scanned or pasted from another device. Returns null when
  /// [raw] is not a sync code (a bare backup token, garbage, a wrong key
  /// length), so the caller can fall back or show an error. Tolerates what
  /// copying between devices does to it: line breaks, invisible spaces,
  /// text around it, dropped base64 padding.
  static SyncPairing? tryParse(String raw) {
    final match = _code.firstMatch(raw.replaceAll(_noise, ''));
    if (match == null) return null;
    final token = match.group(1)!.toLowerCase();
    if (!CloudBackupTokenService.tokenPattern.hasMatch(token)) return null;
    try {
      final key = base64Url.decode(base64Url.normalize(match.group(2)!));
      if (key.length != SyncCrypto.keyLength) return null;
      return SyncPairing(token, key);
    } on FormatException {
      return null;
    }
  }
}

/// Keeps the sync key in the same secure storage as the Hive key and the
/// backup token. Sync is enabled on a device exactly when both a token and
/// a key are stored there.
class SyncKeyService {
  static const _secureStorageKey = 'SyncKey';

  final CloudBackupTokenService _tokenService;
  final _secureStorage = SecureAppStorageProvider.secureAppStorage;

  SyncKeyService(this._tokenService);

  Future<SyncPairing?> read() async {
    final token = await _tokenService.read();
    final key = await _secureStorage.read(key: ProfileScope.secret(_secureStorageKey));
    if (token == null || key == null) return null;
    try {
      return SyncPairing(token, base64Url.decode(key));
    } on FormatException {
      return null;
    }
  }

  Future<bool> isEnabled() async => (await read()) != null;

  /// "Activate sync" on the device that owns the data: reuses its backup
  /// token if it has one and adds a fresh key.
  Future<SyncPairing> enable() async {
    final existing = await read();
    if (existing != null) return existing;
    final token = await _tokenService.read() ?? await _tokenService.generateAndStore();
    final key = SyncCrypto.generateKey();
    await _secureStorage.write(key: ProfileScope.secret(_secureStorageKey), value: base64Url.encode(key));
    return SyncPairing(token, key);
  }

  /// "Link this device" with a code from a device where sync is on.
  Future<void> store(SyncPairing pairing) async {
    await _tokenService.store(pairing.token);
    await _secureStorage.write(key: ProfileScope.secret(_secureStorageKey), value: base64Url.encode(pairing.key));
  }

  /// Stops syncing on this device. Keeps the token, which cloud backup
  /// also uses, and the local data.
  Future<void> disable() => _secureStorage.delete(key: ProfileScope.secret(_secureStorageKey));
}
