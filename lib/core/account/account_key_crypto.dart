import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'package:opennutritracker/core/account/account_key_envelope.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';

/// Password wrap of the data key: the password columns of `account_keys`.
class PasswordWrap {
  final String kdf;
  final int iterations;
  final String salt;
  final String wrappedKey;

  const PasswordWrap({required this.iterations, required this.salt, required this.wrappedKey})
    : kdf = AccountKeyEnvelope.kdfPbkdf2Sha256;

  /// Columns to write when this wrap replaces the stored one. Clears
  /// `needs_rewrap`, since the key is now wrapped with the current password.
  Map<String, dynamic> toJson() => {
    'kdf': kdf,
    'iterations': iterations,
    'salt': salt,
    'wrapped_key': wrappedKey,
    'needs_rewrap': false,
    'version': AccountKeyEnvelope.currentVersion,
  };

  AccountKeyEnvelope toEnvelope() => AccountKeyEnvelope(iterations: iterations, salt: salt, wrappedKey: wrappedKey);
}

/// Recovery wrap of the data key: the recovery columns of `account_keys`.
class RecoveryWrap {
  final String salt;
  final String wrappedKey;

  const RecoveryWrap({required this.salt, required this.wrappedKey});

  Map<String, dynamic> toJson() => {'recovery_salt': salt, 'recovery_wrapped_key': wrappedKey};
}

/// Wraps and unwraps the account's data key (docs/plan-cuentas.md,
/// decision 4). Pure: no I/O, no storage.
///
/// Scheme, version 1 ([AccountKeyEnvelope.currentVersion]):
/// - KEK = PBKDF2-HMAC-SHA256(secret, salt, iterations), 32 bytes, with a
///   fresh 16-byte random salt on every wrap.
/// - wrapped = nonce (12, random) || AES-256-GCM(KEK, data key) || tag (16).
/// - Associated data binds each wrap to its purpose, so a recovery wrap can
///   never be presented as a password wrap or the other way round:
///   [passwordAad] for the password, [recoveryAad] for the recovery key.
/// - Password: UTF-8 bytes of the string as typed (no Unicode
///   normalization), [defaultPasswordIterations] iterations, stored in the
///   row so the count can be raised later without breaking old rows.
/// - Recovery key: the 20 decoded bytes (160 bits), [recoveryIterations]
///   iterations. The count is not stored; it is part of the version.
///
/// Both PBKDF2 and AES-GCM come from package `cryptography`, which uses
/// WebCrypto in browsers (fast, native) and pure Dart elsewhere. On mobile
/// and desktop PBKDF2 runs in a background isolate through [compute] so a
/// login does not freeze the UI.
class AccountKeyCrypto {
  static const int dataKeyLength = SyncCrypto.keyLength;
  static const int defaultPasswordIterations = 310000;
  static const int recoveryIterations = 10000;

  /// Bounds accepted when reading a row; the same as the table's check
  /// constraint, so a row the server accepted is never refused here and a
  /// tampered row cannot make the client spin for minutes.
  static const int minPasswordIterations = 100000;
  static const int maxPasswordIterations = 10000000;

  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int wrappedKeyLength = nonceLength + dataKeyLength + tagLength;

  /// Recovery key: 20 random bytes, 32 Crockford base32 characters shown in
  /// 8 groups of 4.
  static const int recoveryKeyBytes = 20;
  static const int _recoveryKeyChars = recoveryKeyBytes * 8 ~/ 5;
  static const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static final Uint8List passwordAad = ascii.encode('ont-account-key-v1');
  static final Uint8List recoveryAad = ascii.encode('ont-account-recovery-v1');

  final int _passwordIterations;
  final int _recoveryIterations;
  final int _minPasswordIterations;
  final AesGcm _aes = AesGcm.with256bits();

  AccountKeyCrypto()
    : _passwordIterations = defaultPasswordIterations,
      _recoveryIterations = recoveryIterations,
      _minPasswordIterations = minPasswordIterations;

  /// Low iteration counts so tests run in milliseconds. Never use in
  /// production code: the default constructor has no way to lower them.
  @visibleForTesting
  AccountKeyCrypto.forTesting({required int passwordIterations, int recoveryIterations = 1000})
    : _passwordIterations = passwordIterations,
      _recoveryIterations = recoveryIterations,
      _minPasswordIterations = 1;

  /// A new random data key (CSPRNG), the same kind [SyncCrypto] uses.
  Uint8List newDataKey() => SyncCrypto.generateKey();

  Future<PasswordWrap> wrapWithPassword(Uint8List dataKey, String password) async {
    _checkDataKey(dataKey);
    final salt = _randomBytes(saltLength);
    final kek = await _derive(_passwordBytes(password), salt, _passwordIterations);
    final wrapped = await _seal(dataKey, kek, passwordAad);
    return PasswordWrap(iterations: _passwordIterations, salt: base64Encode(salt), wrappedKey: base64Encode(wrapped));
  }

  /// Wraps [dataKey] again under [newPassword] with a fresh salt and nonce:
  /// for a password change and for the `needs_rewrap` flow.
  Future<PasswordWrap> rewrap(Uint8List dataKey, String newPassword) => wrapWithPassword(dataKey, newPassword);

  /// Returns the data key, or throws [WrongPasswordException] when the tag
  /// check fails (wrong password or tampered row) and
  /// [InvalidEnvelopeException] when the row is malformed. Never returns
  /// unauthenticated bytes.
  Future<Uint8List> unwrapWithPassword(AccountKeyEnvelope envelope, String password) async {
    _checkScheme(envelope);
    final iterations = envelope.iterations;
    if (iterations < _minPasswordIterations || iterations > maxPasswordIterations) {
      throw InvalidEnvelopeException('iterations out of range: $iterations');
    }
    final salt = _decode(envelope.salt, 'salt');
    final wrapped = _decode(envelope.wrappedKey, 'wrapped_key');
    _checkLengths(salt, wrapped, 'salt', 'wrapped_key');
    final kek = await _derive(_passwordBytes(password), salt, iterations);
    return _open(wrapped, kek, passwordAad, () => WrongPasswordException(needsRewrap: envelope.needsRewrap));
  }

  /// A new recovery key, like `7K3M-9QXA-...` (8 groups of 4, 160 bits).
  String generateRecoveryKey() => formatRecoveryKey(_randomBytes(recoveryKeyBytes));

  Future<RecoveryWrap> wrapWithRecoveryKey(Uint8List dataKey, String recoveryKey) async {
    _checkDataKey(dataKey);
    final secret = parseRecoveryKey(recoveryKey);
    final salt = _randomBytes(saltLength);
    final kek = await _derive(secret, salt, _recoveryIterations);
    final wrapped = await _seal(dataKey, kek, recoveryAad);
    return RecoveryWrap(salt: base64Encode(salt), wrappedKey: base64Encode(wrapped));
  }

  /// Like [unwrapWithPassword] for the recovery wrap. Throws
  /// [NoRecoveryKeyException] when the row has none,
  /// [InvalidRecoveryKeyFormatException] when [recoveryKey] is not one and
  /// [WrongRecoveryKeyException] when it does not open the row.
  Future<Uint8List> unwrapWithRecoveryKey(AccountKeyEnvelope envelope, String recoveryKey) async {
    _checkScheme(envelope);
    final saltText = envelope.recoverySalt;
    final wrappedText = envelope.recoveryWrappedKey;
    if (saltText == null || wrappedText == null) throw const NoRecoveryKeyException();
    final secret = parseRecoveryKey(recoveryKey);
    final salt = _decode(saltText, 'recovery_salt');
    final wrapped = _decode(wrappedText, 'recovery_wrapped_key');
    _checkLengths(salt, wrapped, 'recovery_salt', 'recovery_wrapped_key');
    final kek = await _derive(secret, salt, _recoveryIterations);
    return _open(wrapped, kek, recoveryAad, () => const WrongRecoveryKeyException());
  }

  /// Crockford base32 in groups of 4 joined by '-'.
  @visibleForTesting
  static String formatRecoveryKey(Uint8List bytes) {
    if (bytes.length != recoveryKeyBytes) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be $recoveryKeyBytes bytes');
    }
    final chars = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        chars.write(_crockford[(buffer >> bits) & 31]);
      }
      buffer &= (1 << bits) - 1;
    }
    final text = chars.toString();
    return [for (var i = 0; i < text.length; i += 4) text.substring(i, i + 4)].join('-');
  }

  /// Decodes a recovery key as typed: any case, spaces, line breaks, any
  /// dashes or none, and Crockford's look-alikes (O for 0, I and L for 1).
  static Uint8List parseRecoveryKey(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s\-‐-―−]'), '');
    if (cleaned.length != _recoveryKeyChars) {
      throw InvalidRecoveryKeyFormatException('expected $_recoveryKeyChars characters, got ${cleaned.length}');
    }
    final out = Uint8List(recoveryKeyBytes);
    var buffer = 0;
    var bits = 0;
    var index = 0;
    for (final rune in cleaned.runes) {
      final value = _crockfordValue(String.fromCharCode(rune));
      if (value < 0) throw const InvalidRecoveryKeyFormatException('invalid character');
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out[index++] = (buffer >> bits) & 0xff;
        buffer &= (1 << bits) - 1;
      }
    }
    return out;
  }

  static int _crockfordValue(String char) => switch (char) {
    'O' => 0,
    'I' || 'L' => 1,
    _ => _crockford.indexOf(char),
  };

  static void _checkDataKey(Uint8List dataKey) {
    if (dataKey.length != dataKeyLength) {
      throw ArgumentError.value(dataKey.length, 'dataKey', 'must be $dataKeyLength bytes');
    }
  }

  static Uint8List _passwordBytes(String password) {
    if (password.isEmpty) throw ArgumentError.value(password, 'password', 'must not be empty');
    return utf8.encode(password);
  }

  static void _checkScheme(AccountKeyEnvelope envelope) {
    if (envelope.kdf != AccountKeyEnvelope.kdfPbkdf2Sha256) {
      throw InvalidEnvelopeException('unknown kdf: ${envelope.kdf}');
    }
    if (envelope.version != AccountKeyEnvelope.currentVersion) {
      throw InvalidEnvelopeException('unknown version: ${envelope.version}');
    }
  }

  static Uint8List _decode(String text, String column) {
    try {
      return base64Decode(text);
    } on FormatException {
      throw InvalidEnvelopeException('$column is not base64');
    }
  }

  static void _checkLengths(Uint8List salt, Uint8List wrapped, String saltColumn, String wrappedColumn) {
    if (salt.length < saltLength) {
      throw InvalidEnvelopeException('$saltColumn too short: ${salt.length} bytes');
    }
    if (wrapped.length != wrappedKeyLength) {
      throw InvalidEnvelopeException('$wrappedColumn must be $wrappedKeyLength bytes, got ${wrapped.length}');
    }
  }

  Future<Uint8List> _seal(Uint8List dataKey, Uint8List kek, Uint8List aad) async {
    final box = await _aes.encrypt(dataKey, secretKey: SecretKey(kek), nonce: _randomBytes(nonceLength), aad: aad);
    return box.concatenation();
  }

  Future<Uint8List> _open(
    Uint8List wrapped,
    Uint8List kek,
    Uint8List aad,
    AccountKeyException Function() onAuthFailure,
  ) async {
    final box = SecretBox.fromConcatenation(wrapped, nonceLength: nonceLength, macLength: tagLength);
    final List<int> clear;
    try {
      clear = await _aes.decrypt(box, secretKey: SecretKey(kek), aad: aad);
    } on SecretBoxAuthenticationError {
      throw onAuthFailure();
    }
    // Unreachable with the length checks above (GCM keeps the length), kept
    // so a future layout change cannot hand out a short key.
    if (clear.length != dataKeyLength) {
      throw InvalidEnvelopeException('unwrapped key has ${clear.length} bytes');
    }
    return Uint8List.fromList(clear);
  }

  static Future<Uint8List> _derive(Uint8List secret, Uint8List salt, int iterations) =>
      compute(_pbkdf2, _KdfInput(secret, salt, iterations), debugLabel: 'pbkdf2');

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }
}

class _KdfInput {
  final Uint8List secret;
  final Uint8List salt;
  final int iterations;

  const _KdfInput(this.secret, this.salt, this.iterations);
}

/// Top level so [compute] can run it in another isolate. In a browser
/// [compute] runs it inline and `cryptography` hands it to WebCrypto.
Future<Uint8List> _pbkdf2(_KdfInput input) async {
  final kdf = Pbkdf2.hmacSha256(iterations: input.iterations, bits: AccountKeyCrypto.dataKeyLength * 8);
  final key = await kdf.deriveKey(secretKey: SecretKey(input.secret), nonce: input.salt);
  return Uint8List.fromList(await key.extractBytes());
}
