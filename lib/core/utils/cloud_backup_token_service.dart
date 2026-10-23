import 'dart:math';
import 'dart:typed_data';

import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// The 256-bit pairing token for the cloud-backup feature (Fase Cuenta).
/// It's the only credential the app ever sends to the private Supabase
/// Storage bucket set up in docs/cloud-backup-setup.md -- there's no login,
/// so knowing this token *is* having access, checked there against the RLS
/// pattern `[a-f0-9]{64}` on the object path. Kept in the same secure
/// storage as the Hive encryption key (see SecureAppStorageProvider), for
/// the same reason: it's a device-local secret, not app data.
class CloudBackupTokenService {
  static const _secureStorageKey = 'CloudBackupToken';

  /// Matches exactly what FA-09's RLS policy expects: 64 lowercase hex
  /// characters (32 random bytes). Used both to validate a freshly
  /// generated token and to reject garbage typed/scanned during pairing.
  static final RegExp tokenPattern = RegExp(r'^[a-f0-9]{64}$');

  final _secureStorage = SecureAppStorageProvider.secureAppStorage;

  /// The token active on this device, or null if cloud backup hasn't been
  /// set up here yet (neither generated nor paired in).
  Future<String?> read() => _secureStorage.read(key: ProfileScope.secret(_secureStorageKey));

  Future<bool> hasToken() => _secureStorage.containsKey(key: ProfileScope.secret(_secureStorageKey));

  /// Generates a fresh random token and persists it -- the "activate cloud
  /// backup" action, done once on whichever device owns the data.
  Future<String> generateAndStore() async {
    final token = generateToken();
    await store(token);
    return token;
  }

  /// The pure generation step, split out from [generateAndStore] so it's
  /// unit-testable without a working secure-storage backend: 32 bytes from
  /// a CSPRNG, lowercase-hex-encoded to match [tokenPattern] and FA-09's
  /// RLS policy exactly.
  static String generateToken() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Persists a token obtained from elsewhere (QR scan / pasted text) --
  /// the "link this device" action. Throws [ArgumentError] if [token]
  /// doesn't match [tokenPattern], so a mis-scan or bad paste fails loudly
  /// instead of silently saving something the backend will just reject.
  Future<void> store(String token) async {
    if (!tokenPattern.hasMatch(token)) {
      throw ArgumentError.value(
        token,
        'token',
        'Not a valid cloud-backup pairing token',
      );
    }
    await _secureStorage.write(key: ProfileScope.secret(_secureStorageKey), value: token);
  }

  Future<void> clear() => _secureStorage.delete(key: ProfileScope.secret(_secureStorageKey));
}
