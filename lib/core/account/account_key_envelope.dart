/// One row of `public.account_keys` (supabase/migrations/20261103_accounts.sql):
/// the account's data key, wrapped. The server never sees the data key.
///
/// Binary fields hold standard, padded base64:
/// - [salt]: PBKDF2 salt for the password wrap.
/// - [wrappedKey]: nonce (12) || AES-256-GCM ciphertext (32) || tag (16) of
///   the data key under PBKDF2-HMAC-SHA256(password, [salt], [iterations]).
/// - [recoverySalt], [recoveryWrappedKey]: the same, under the optional
///   recovery key. Both null when no recovery key was set.
///
/// [version] is the wrapping scheme (associated data strings, recovery
/// iterations, byte layout), not a counter. A client refuses versions it does
/// not know instead of guessing.
class AccountKeyEnvelope {
  static const String kdfPbkdf2Sha256 = 'pbkdf2-sha256';
  static const int currentVersion = 1;

  final String kdf;
  final int iterations;
  final String salt;
  final String wrappedKey;
  final String? recoverySalt;
  final String? recoveryWrappedKey;

  /// Set after a password reset done on a device that did not hold the data
  /// key: [wrappedKey] is still under the old password, so a device that
  /// holds the key must wrap it again with the new one.
  final bool needsRewrap;
  final int version;

  const AccountKeyEnvelope({
    this.kdf = kdfPbkdf2Sha256,
    required this.iterations,
    required this.salt,
    required this.wrappedKey,
    this.recoverySalt,
    this.recoveryWrappedKey,
    this.needsRewrap = false,
    this.version = currentVersion,
  });

  bool get hasRecoveryKey => recoverySalt != null && recoveryWrappedKey != null;

  /// Reads a row as PostgREST returns it. Extra columns (`user_id`,
  /// `updated_at`) are ignored. Throws [FormatException] on a missing or
  /// mistyped column.
  factory AccountKeyEnvelope.fromJson(Map<String, dynamic> json) {
    T field<T>(String name) {
      final value = json[name];
      if (value is! T) {
        throw FormatException('account_keys.$name: expected $T, got ${value.runtimeType}');
      }
      return value;
    }

    return AccountKeyEnvelope(
      kdf: field<String>('kdf'),
      iterations: field<int>('iterations'),
      salt: field<String>('salt'),
      wrappedKey: field<String>('wrapped_key'),
      recoverySalt: field<String?>('recovery_salt'),
      recoveryWrappedKey: field<String?>('recovery_wrapped_key'),
      needsRewrap: field<bool?>('needs_rewrap') ?? false,
      version: field<int?>('version') ?? currentVersion,
    );
  }

  /// Every column the client owns. `user_id` is left out on purpose: the
  /// server fills it from the JWT (`default auth.uid()`).
  Map<String, dynamic> toJson() => {
    'kdf': kdf,
    'iterations': iterations,
    'salt': salt,
    'wrapped_key': wrappedKey,
    'recovery_salt': recoverySalt,
    'recovery_wrapped_key': recoveryWrappedKey,
    'needs_rewrap': needsRewrap,
    'version': version,
  };

  AccountKeyEnvelope copyWith({
    String? kdf,
    int? iterations,
    String? salt,
    String? wrappedKey,
    String? recoverySalt,
    String? recoveryWrappedKey,
    bool? needsRewrap,
    int? version,
  }) => AccountKeyEnvelope(
    kdf: kdf ?? this.kdf,
    iterations: iterations ?? this.iterations,
    salt: salt ?? this.salt,
    wrappedKey: wrappedKey ?? this.wrappedKey,
    recoverySalt: recoverySalt ?? this.recoverySalt,
    recoveryWrappedKey: recoveryWrappedKey ?? this.recoveryWrappedKey,
    needsRewrap: needsRewrap ?? this.needsRewrap,
    version: version ?? this.version,
  );

  @override
  bool operator ==(Object other) =>
      other is AccountKeyEnvelope &&
      other.kdf == kdf &&
      other.iterations == iterations &&
      other.salt == salt &&
      other.wrappedKey == wrappedKey &&
      other.recoverySalt == recoverySalt &&
      other.recoveryWrappedKey == recoveryWrappedKey &&
      other.needsRewrap == needsRewrap &&
      other.version == version;

  @override
  int get hashCode =>
      Object.hash(kdf, iterations, salt, wrappedKey, recoverySalt, recoveryWrappedKey, needsRewrap, version);

  /// Never prints key material.
  @override
  String toString() =>
      'AccountKeyEnvelope(kdf: $kdf, iterations: $iterations, version: $version, '
      'needsRewrap: $needsRewrap, hasRecoveryKey: $hasRecoveryKey)';
}
