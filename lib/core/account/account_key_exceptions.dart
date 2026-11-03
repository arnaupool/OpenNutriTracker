/// Base class for every failure of the account key layer, so callers can
/// catch the whole family in one place.
sealed class AccountKeyException implements Exception {
  final String message;

  const AccountKeyException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// The password does not open the wrapped key (GCM tag check failed).
///
/// [needsRewrap] is true when the server row is flagged after a password
/// reset: the key is still wrapped with the previous password, so the new one
/// cannot open it until a device that holds the key wraps it again (or the
/// recovery key is used).
final class WrongPasswordException extends AccountKeyException {
  final bool needsRewrap;

  const WrongPasswordException({this.needsRewrap = false}) : super('wrong password');
}

/// The recovery key is well formed but does not open the wrapped key.
final class WrongRecoveryKeyException extends AccountKeyException {
  const WrongRecoveryKeyException() : super('wrong recovery key');
}

/// The text is not a recovery key (wrong length or characters), so it was
/// not even tried against the server row.
final class InvalidRecoveryKeyFormatException extends AccountKeyException {
  const InvalidRecoveryKeyFormatException(super.message);
}

/// The server row is malformed or uses a scheme this client does not know
/// (kdf, version, iteration count out of range, bad base64, wrong lengths).
final class InvalidEnvelopeException extends AccountKeyException {
  const InvalidEnvelopeException(super.message);
}

/// The account has no `account_keys` row yet.
final class AccountKeyNotFoundException extends AccountKeyException {
  const AccountKeyNotFoundException() : super('no account key row');
}

/// The account already has an `account_keys` row; creating another would
/// orphan everything encrypted under the existing key.
final class AccountKeyConflictException extends AccountKeyException {
  const AccountKeyConflictException() : super('account key row already exists');
}

/// The account has no recovery key set.
final class NoRecoveryKeyException extends AccountKeyException {
  const NoRecoveryKeyException() : super('no recovery key set');
}

/// Unexpected HTTP answer from PostgREST.
final class AccountKeyRemoteException extends AccountKeyException {
  final int statusCode;
  final String body;

  AccountKeyRemoteException(this.statusCode, this.body) : super('HTTP $statusCode: $body');
}
