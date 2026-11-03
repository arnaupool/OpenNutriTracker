import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Turns the password the user types into the secret Supabase Auth sees, so
/// the server never learns the password that wraps the data key
/// (`AccountKeyCrypto`).
///
/// Scheme `ont-auth-v1`:
/// - master = PBKDF2-HMAC-SHA256(utf8(password), utf8('ont-auth-v1:' +
///   normalized email), 310000 iterations, 32 bytes);
/// - secret = base64url(HKDF-SHA256(master, salt empty, info
///   'ont-auth-v1', 32 bytes)), without padding (43 characters).
///
/// The email is normalized with [normalizeEmail], so 'A@x.com' and 'a@x.com'
/// give the same secret. The password is used as typed (no Unicode
/// normalization), like `AccountKeyCrypto`. The key wrap uses its own random
/// salt, so the Auth secret reveals nothing about the wrapping key.
///
/// Every call that sends a password to Supabase Auth (sign up, sign in,
/// password update after a reset, change password) must send this secret.
class AccountAuthSecret {
  static const int defaultIterations = 310000;
  static const String label = 'ont-auth-v1';

  final int iterations;

  const AccountAuthSecret() : iterations = defaultIterations;

  /// Low iteration count so tests run fast. Never use in production code.
  @visibleForTesting
  const AccountAuthSecret.forTesting({required this.iterations});

  /// Lower-case, trimmed: the form Supabase Auth stores too.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<String> derive(String password, String email) {
    if (password.isEmpty) throw ArgumentError.value('<redacted>', 'password', 'must not be empty');
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) throw ArgumentError.value(email, 'email', 'must not be empty');
    final input = _AuthSecretInput(utf8.encode(password), utf8.encode('$label:$normalized'), iterations);
    return compute(_deriveAuthSecret, input, debugLabel: 'auth-secret');
  }
}

class _AuthSecretInput {
  final Uint8List password;
  final Uint8List salt;
  final int iterations;

  const _AuthSecretInput(this.password, this.salt, this.iterations);
}

/// Top level so [compute] can run it in another isolate. In a browser
/// [compute] runs it inline and `cryptography` hands PBKDF2 to WebCrypto.
Future<String> _deriveAuthSecret(_AuthSecretInput input) async {
  final master = await Pbkdf2.hmacSha256(
    iterations: input.iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(input.password), nonce: input.salt);
  final secret = await Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(secretKey: master, info: utf8.encode(AccountAuthSecret.label));
  return base64Url.encode(await secret.extractBytes()).replaceAll('=', '');
}
