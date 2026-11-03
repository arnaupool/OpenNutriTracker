/// Base class for every failure of the account session layer (Supabase Auth
/// and per-profile sessions), so the UI can catch the whole family in one
/// place. Key failures keep their own family, `AccountKeyException`.
sealed class AccountSessionException implements Exception {
  final String message;

  const AccountSessionException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Sign-ups are closed (`app_settings.signups_open` is false, or the server
/// refused the new user with `signups_closed`).
final class SignupsClosedException extends AccountSessionException {
  const SignupsClosedException() : super('sign-ups are closed');
}

/// Wrong email or password.
final class InvalidCredentialsException extends AccountSessionException {
  const InvalidCredentialsException() : super('invalid login credentials');
}

/// The account exists but its email was never confirmed: the UI asks for the
/// 6-digit code (and can resend it).
final class EmailNotConfirmedException extends AccountSessionException {
  const EmailNotConfirmedException() : super('email not confirmed');
}

/// The 6-digit code is wrong or has expired.
final class InvalidCodeException extends AccountSessionException {
  const InvalidCodeException() : super('code is invalid or has expired');
}

/// Too many emails or requests; the UI asks the user to wait.
final class AuthRateLimitedException extends AccountSessionException {
  const AuthRateLimitedException() : super('rate limited');
}

/// The server no longer accepts the stored refresh token (signed out
/// elsewhere, password reset, account deleted). The session was removed;
/// the data key is kept so signing in again needs no recovery key.
final class SessionExpiredException extends AccountSessionException {
  const SessionExpiredException() : super('session expired');
}

/// The profile has no session (local profile, or signed out).
final class NotSignedInException extends AccountSessionException {
  const NotSignedInException() : super('profile is not signed in');
}

/// The account is already linked to another profile of this device
/// ([profileId]); the UI offers to switch to it instead.
final class AccountAlreadyOnDeviceException extends AccountSessionException {
  final String profileId;

  const AccountAlreadyOnDeviceException(this.profileId) : super('account already linked to another profile');
}

/// The profile belongs to another account ([email]); its data must never be
/// merged into a different one.
final class ProfileHasOtherAccountException extends AccountSessionException {
  final String email;

  const ProfileHasOtherAccountException(this.email) : super('profile is linked to another account');
}

/// No answer from the server (offline, timeout).
final class AccountNetworkException extends AccountSessionException {
  final Object cause;

  AccountNetworkException(this.cause) : super('network error: $cause');
}

/// Any other error answer from Supabase Auth or PostgREST.
final class AccountAuthRemoteException extends AccountSessionException {
  final int statusCode;
  final String? errorCode;

  AccountAuthRemoteException(this.statusCode, this.errorCode, String detail)
    : super('HTTP $statusCode${errorCode == null ? '' : ' $errorCode'}: $detail');
}
