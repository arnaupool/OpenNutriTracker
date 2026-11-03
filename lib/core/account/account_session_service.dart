import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:opennutritracker/core/account/account_auth_api.dart';
import 'package:opennutritracker/core/account/account_auth_secret.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_store.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';

/// Where a profile stands with its account, for the account picker and the
/// app start.
enum AccountStatus {
  /// No account: the profile works as before, without sync.
  local,

  /// Linked to an account but without a session on this device (signed
  /// out, or the server dropped the session). [AccountSessionService.signIn]
  /// with the same account brings it back.
  signedOut,

  /// Signed in and holding the data key, but the password was reset
  /// elsewhere and the key on the server is still wrapped with the old one.
  /// The UI asks for the current password and calls
  /// [AccountSessionService.rewrapAfterReset].
  needsRewrap,

  /// Signed in with the data key: sync can run.
  ready,
}

enum SignUpResult {
  /// The server sent a 6-digit code: call [AccountSessionService.verifySignupCode].
  codeSent,

  /// The project confirms emails automatically; the profile is signed in.
  signedIn,
}

enum SignInResult {
  /// Signed in, data key stored on this device.
  ready,

  /// The password signs in but does not open the data key (it was reset on
  /// a device without the key) and this device does not hold it. Nothing
  /// was stored; the UI offers [AccountSessionService.recoverWithRecoveryKey].
  needsRecoveryKey,
}

enum PasswordResetResult {
  /// This device held the data key and wrapped it with the new password.
  rewrapped,

  /// No profile on this device holds the key: the row is flagged
  /// `needs_rewrap` until a device that holds it wraps it again, or the
  /// recovery key is used.
  needsRewrap,
}

/// Supabase Auth accounts, one per local profile (docs/plan-cuentas.md,
/// decisions 1, 2 and 10; task B5).
///
/// Each profile has its own session (refresh token) and data key in secure
/// storage ([AccountSessionStore]), so several accounts stay signed in on one
/// device and switching needs no password. Nothing here goes through the
/// `Supabase.instance` singleton.
///
/// Passwords: Supabase Auth only ever sees the secret from
/// [AccountAuthSecret]; the password as typed only wraps and unwraps the
/// data key through [AccountKeyService].
///
/// Every method that takes a `profileId` expects a profile that already
/// exists in [ProfileStore]. Signing in or creating an account on a local
/// profile attaches it and keeps its data (B6 merges it). A profile linked
/// to one account never accepts another ([ProfileHasOtherAccountException]),
/// and an account lives on at most one profile of this device
/// ([AccountAlreadyOnDeviceException]).
///
/// Errors: [AccountSessionException] for Auth and session problems,
/// `AccountKeyException` for the data key (wrong recovery key and so on).
class AccountSessionService {
  /// The access token is refreshed when it expires within this margin.
  static const Duration refreshMargin = Duration(seconds: 60);

  final _log = Logger('AccountSessionService');
  final AccountAuthApi _api;
  final AccountKeyService _keys;
  final AccountSessionStore _store;
  final ProfileStore _profiles;
  final AccountAuthSecret _secret;
  final DateTime Function() _now;

  final Map<String, Future<AuthSession>> _refreshing = {};

  AccountSessionService({
    required AccountAuthApi api,
    required AccountKeyService keys,
    required AccountSessionStore store,
    required ProfileStore profiles,
    AccountAuthSecret secret = const AccountAuthSecret(),
    DateTime Function()? now,
  }) : _api = api,
       _keys = keys,
       _store = store,
       _profiles = profiles,
       _secret = secret,
       _now = now ?? DateTime.now;

  // Sign-up

  /// Whether new accounts can be created; the server enforces it anyway.
  Future<bool> signupsOpen() => _api.signupsOpen();

  /// Creates the account for [profileId]. Throws [SignupsClosedException]
  /// when sign-ups are closed. Usually returns [SignUpResult.codeSent]: the
  /// user then types the emailed code into [verifySignupCode].
  Future<SignUpResult> signUp(String profileId, String email, String password) async {
    final normalized = AccountAuthSecret.normalizeEmail(email);
    await _checkAttachable(profileId, email: normalized);
    if (!await _api.signupsOpen()) throw const SignupsClosedException();
    final secret = await _secret.derive(password, normalized);
    final AuthSession? session;
    try {
      session = await _api.signUp(normalized, secret);
    } on AccountAuthRemoteException catch (e) {
      // The gate trigger surfaces as a generic database error; ask again to
      // tell a closed sign-up apart from other failures.
      if (e.statusCode >= 500 && !await _api.signupsOpen()) throw const SignupsClosedException();
      rethrow;
    }
    if (session == null) return SignUpResult.codeSent;
    await _attach(profileId, session, password);
    return SignUpResult.signedIn;
  }

  Future<void> resendSignupCode(String email) => _api.resendSignupCode(AccountAuthSecret.normalizeEmail(email));

  /// Confirms the account with the emailed code, signs [profileId] in and
  /// creates the data key wrapped with [password]. [password] must be the
  /// one given to [signUp]: it is checked by signing in, so a typo here
  /// throws [InvalidCredentialsException] instead of wrapping the key with
  /// a password Auth does not know (the account stays confirmed; a later
  /// [signIn] with the right password creates the key). Returns what
  /// [signIn] would; for a new account always [SignInResult.ready].
  Future<SignInResult> verifySignupCode(String profileId, String email, String code, String password) async {
    final normalized = AccountAuthSecret.normalizeEmail(email);
    await _checkAttachable(profileId, email: normalized);
    final verified = await _api.verifyOtp(normalized, code, 'signup');
    try {
      final session = await _api.signIn(normalized, await _secret.derive(password, normalized));
      await _checkAttachableOrRevoke(profileId, session);
      return await _unlockAndAttach(profileId, session, password);
    } finally {
      await _revokeQuietly(verified);
    }
  }

  // Sign-in

  /// Signs [profileId] in. Returns [SignInResult.needsRecoveryKey] when the
  /// password was reset and only the recovery key can open the data key.
  /// Throws [InvalidCredentialsException], [EmailNotConfirmedException]
  /// (the UI asks for the code), [AccountAlreadyOnDeviceException] or
  /// [ProfileHasOtherAccountException].
  Future<SignInResult> signIn(String profileId, String email, String password) async {
    final normalized = AccountAuthSecret.normalizeEmail(email);
    await _checkAttachable(profileId, email: normalized);
    final session = await _api.signIn(normalized, await _secret.derive(password, normalized));
    await _checkAttachableOrRevoke(profileId, session);
    return _unlockAndAttach(profileId, session, password);
  }

  /// After [SignInResult.needsRecoveryKey]: signs in again, opens the data
  /// key with [recoveryKey] and wraps it with [password]. Throws
  /// `WrongRecoveryKeyException`, `InvalidRecoveryKeyFormatException` or
  /// `NoRecoveryKeyException` from the key layer.
  Future<void> recoverWithRecoveryKey(String profileId, String email, String password, String recoveryKey) async {
    final normalized = AccountAuthSecret.normalizeEmail(email);
    await _checkAttachable(profileId, email: normalized);
    final session = await _api.signIn(normalized, await _secret.derive(password, normalized));
    await _checkAttachableOrRevoke(profileId, session);
    try {
      final dataKey = await _keys.unlockWithRecoveryKey(recoveryKey, session.accessToken);
      await _keys.changePassword(dataKey, password, session.accessToken);
      await _persist(profileId, session, dataKey);
    } on Object {
      await _revokeQuietly(session);
      rethrow;
    }
  }

  // Password reset

  /// Emails a 6-digit reset code.
  Future<void> requestPasswordReset(String email) => _api.requestPasswordReset(AccountAuthSecret.normalizeEmail(email));

  /// Sets [newPassword] with the emailed code. When a profile of this device
  /// holds the account's data key, the key is wrapped with [newPassword]
  /// first; otherwise the row is flagged `needs_rewrap`. Signs no profile
  /// in: the UI calls [signIn] with the new password afterwards.
  Future<PasswordResetResult> completePasswordReset(String email, String code, String newPassword) async {
    final normalized = AccountAuthSecret.normalizeEmail(email);
    final session = await _api.verifyOtp(normalized, code, 'recovery');
    try {
      final secret = await _secret.derive(newPassword, normalized);
      final held = await _heldDataKey(session.userId);
      if (held != null) {
        // Wrap first: if the Auth update then fails, retrying the reset
        // fixes it, and signing in with the old password on this device
        // wraps the key back.
        await _keys.changePassword(held, newPassword, session.accessToken);
        await _api.updatePassword(session.accessToken, secret);
        return PasswordResetResult.rewrapped;
      }
      // Flag first: a flag left behind by a failed update is harmless (the
      // next sign-in that opens the key clears it).
      try {
        await _keys.markNeedsRewrap(session.accessToken);
      } on AccountKeyNotFoundException {
        // Confirmed but no key yet: the next sign-in creates it.
      }
      await _api.updatePassword(session.accessToken, secret);
      return PasswordResetResult.needsRewrap;
    } finally {
      await _revokeQuietly(session);
    }
  }

  /// On a device that holds the key, after [status] returned
  /// [AccountStatus.needsRewrap]: checks [password] (the one set by the
  /// reset) by signing in with it, then wraps the key with it. Throws
  /// [InvalidCredentialsException] for a wrong password.
  Future<void> rewrapAfterReset(String profileId, String password) async {
    final (link, dataKey) = await _requireKey(profileId);
    final session = await _api.signIn(link.email, await _secret.derive(password, link.email));
    try {
      await _keys.changePassword(dataKey, password, session.accessToken);
    } on Object {
      await _revokeQuietly(session);
      rethrow;
    }
    await _adoptSession(profileId, session);
  }

  // Change password

  /// Changes the password of a signed-in profile. Checks [currentPassword]
  /// by signing in, wraps the data key with [newPassword], then updates the
  /// Auth password. If the Auth update fails the key is wrapped back with
  /// [currentPassword], so the two never disagree, and the error is
  /// rethrown.
  Future<void> changePassword(String profileId, String currentPassword, String newPassword) async {
    final (link, dataKey) = await _requireKey(profileId);
    final session = await _api.signIn(link.email, await _secret.derive(currentPassword, link.email));
    try {
      final newSecret = await _secret.derive(newPassword, link.email);
      await _keys.changePassword(dataKey, newPassword, session.accessToken);
      try {
        await _api.updatePassword(session.accessToken, newSecret);
      } on Object catch (e) {
        try {
          await _keys.changePassword(dataKey, currentPassword, session.accessToken);
        } on Object catch (rollback) {
          // Signing in with the current password on this device rewraps.
          _log.severe('password change rollback failed after $e', rollback);
        }
        rethrow;
      }
    } on Object {
      await _revokeQuietly(session);
      rethrow;
    }
    await _adoptSession(profileId, session);
  }

  // Session

  /// Revokes the profile's session on the server (best effort: offline, the
  /// local copy goes anyway) and deletes the session and the data key from
  /// this device. Keeps the profile, its Hive data and its account link:
  /// the account picker (C8) checks for unsynced changes (B6) and then
  /// deletes the profile with [ProfileStore.remove].
  Future<void> signOut(String profileId) async {
    final session = await _store.readSession(profileId);
    if (session != null) {
      try {
        await _api.signOut(await accessToken(profileId));
      } on Object catch (e) {
        _log.warning('sign-out could not revoke the session: $e');
      }
    }
    await _store.deleteSession(profileId);
    await _store.deleteDataKey(profileId);
  }

  /// A valid access token for [profileId], refreshed when it expires within
  /// [refreshMargin]. Concurrent calls share one refresh. Throws
  /// [NotSignedInException] without a session and [SessionExpiredException]
  /// when the server refuses the refresh token (the session is then deleted,
  /// the data key kept).
  Future<String> accessToken(String profileId) async => (await _freshSession(profileId)).accessToken;

  /// The unwrapped data key of a signed-in profile, for sync (B6).
  Future<Uint8List?> dataKey(String profileId) async {
    final link = (await _profiles.byId(profileId))?.account;
    if (link == null) return null;
    return _store.readDataKey(profileId, link.userId);
  }

  /// For the app start and every account switch. Asks the server whether
  /// the key needs a rewrap; offline it trusts the local state.
  Future<AccountStatus> status(String profileId) async {
    final link = (await _profiles.byId(profileId))?.account;
    if (link == null) return AccountStatus.local;
    final session = await _store.readSession(profileId);
    final dataKey = await _store.readDataKey(profileId, link.userId);
    if (session == null || dataKey == null || session.userId != link.userId) return AccountStatus.signedOut;
    try {
      final envelope = await _keys.fetchEnvelope(await accessToken(profileId));
      return envelope != null && envelope.needsRewrap ? AccountStatus.needsRewrap : AccountStatus.ready;
    } on SessionExpiredException {
      return AccountStatus.signedOut;
    } on Exception catch (e) {
      // Offline or server trouble: keep working with the local key.
      if (e is AccountNetworkException ||
          e is AccountAuthRemoteException ||
          e is AccountKeyRemoteException ||
          e is http.ClientException ||
          e is TimeoutException) {
        _log.info('account status check failed, trusting local state: $e');
        return AccountStatus.ready;
      }
      rethrow;
    }
  }

  // Internals

  Future<AuthSession> _freshSession(String profileId) async {
    final session = await _store.readSession(profileId);
    if (session == null) throw const NotSignedInException();
    if (!session.expiresWithin(refreshMargin, _now().toUtc())) return session;
    // Block body: whenComplete would wait on a returned future, here itself.
    return _refreshing[profileId] ??= _refresh(profileId, session).whenComplete(() {
      _refreshing.remove(profileId);
    });
  }

  Future<AuthSession> _refresh(String profileId, AuthSession old) async {
    final AuthSession fresh;
    try {
      fresh = await _api.refresh(old.refreshToken);
    } on SessionExpiredException {
      if ((await _store.readSession(profileId))?.refreshToken == old.refreshToken) {
        await _store.deleteSession(profileId);
      }
      rethrow;
    }
    if (fresh.userId != old.userId) throw AccountAuthRemoteException(200, null, 'refresh returned another user');
    // Signed out or replaced meanwhile: do not bring the old session back.
    if ((await _store.readSession(profileId))?.refreshToken != old.refreshToken) {
      await _revokeQuietly(fresh);
      throw const NotSignedInException();
    }
    await _store.writeSession(profileId, fresh);
    return fresh;
  }

  /// Opens or creates the data key for a fresh [session] and stores it with
  /// the session and the profile link.
  Future<SignInResult> _unlockAndAttach(String profileId, AuthSession session, String password) async {
    try {
      final token = session.accessToken;
      final envelope = await _keys.fetchEnvelope(token);
      Uint8List dataKey;
      if (envelope == null) {
        dataKey = await _keys.createForNewAccount(password, token);
      } else {
        try {
          dataKey = await _keys.unlock(password, token);
          if (envelope.needsRewrap) await _keys.changePassword(dataKey, password, token);
        } on WrongPasswordException {
          // Auth accepted the password, so it is the current one; the key is
          // still wrapped with an older one. Only a device that holds the key
          // (this profile, signed out after a reset) can fix it here.
          final held = await _store.readDataKey(profileId, session.userId);
          if (held == null) {
            await _revokeQuietly(session);
            return SignInResult.needsRecoveryKey;
          }
          await _keys.changePassword(held, password, token);
          dataKey = held;
        }
      }
      await _persist(profileId, session, dataKey);
      return SignInResult.ready;
    } on Object {
      await _revokeQuietly(session);
      rethrow;
    }
  }

  Future<void> _attach(String profileId, AuthSession session, String password) async {
    await _checkAttachableOrRevoke(profileId, session);
    await _unlockAndAttach(profileId, session, password);
  }

  /// Key first, then session, then link: a crash in between leaves a
  /// profile that [status] reports as signed out, never one with a session
  /// and no key.
  Future<void> _persist(String profileId, AuthSession session, Uint8List dataKey) async {
    await _store.writeDataKey(profileId, session.userId, dataKey);
    await _adoptSession(profileId, session);
    await _profiles.setAccount(profileId, AccountLink(userId: session.userId, email: _emailOf(session)));
  }

  /// Stores [session] for [profileId] and revokes the one it replaces.
  Future<void> _adoptSession(String profileId, AuthSession session) async {
    final previous = await _store.readSession(profileId);
    await _store.writeSession(profileId, session);
    if (previous != null && previous.refreshToken != session.refreshToken) await _revokeQuietly(previous);
  }

  Future<(AccountLink, Uint8List)> _requireKey(String profileId) async {
    final link = (await _profiles.byId(profileId))?.account;
    if (link == null) throw const NotSignedInException();
    final dataKey = await _store.readDataKey(profileId, link.userId);
    if (dataKey == null) throw const NotSignedInException();
    return (link, dataKey);
  }

  /// The data key of [userId] held by any profile of this device.
  Future<Uint8List?> _heldDataKey(String userId) async {
    for (final profile in await _profiles.all()) {
      if (profile.account?.userId != userId) continue;
      final key = await _store.readDataKey(profile.id, userId);
      if (key != null) return key;
    }
    return null;
  }

  /// Refuses to put an account on [profileId] when the profile belongs to
  /// another account, or the account already lives on another profile.
  /// Matches by [email] before signing in and by [userId] after.
  Future<void> _checkAttachable(String profileId, {String? email, String? userId}) async {
    final profiles = await _profiles.all();
    final target = profiles.where((p) => p.id == profileId).firstOrNull;
    if (target == null) throw ArgumentError.value(profileId, 'profileId', 'unknown profile');
    bool same(AccountLink link) => userId != null ? link.userId == userId : link.email == email;
    final own = target.account;
    if (own != null && !same(own)) throw ProfileHasOtherAccountException(own.email);
    for (final other in profiles) {
      final link = other.account;
      if (other.id != profileId && link != null && same(link)) throw AccountAlreadyOnDeviceException(other.id);
    }
  }

  Future<void> _checkAttachableOrRevoke(String profileId, AuthSession session) async {
    try {
      await _checkAttachable(profileId, userId: session.userId);
    } on Object {
      await _revokeQuietly(session);
      rethrow;
    }
  }

  String _emailOf(AuthSession session) => AccountAuthSecret.normalizeEmail(session.email);

  Future<void> _revokeQuietly(AuthSession session) async {
    try {
      await _api.signOut(session.accessToken);
    } on Object catch (e) {
      _log.fine('could not revoke a session: $e');
    }
  }
}
