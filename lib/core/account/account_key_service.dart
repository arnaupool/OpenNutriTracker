import 'dart:typed_data';

import 'package:opennutritracker/core/account/account_key_crypto.dart';
import 'package:opennutritracker/core/account/account_key_envelope.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/account/account_key_remote.dart';

/// The account's data key end to end: create, unlock, rewrap and recovery
/// (docs/plan-cuentas.md, decision 4). Stores nothing locally; the caller
/// keeps the returned data key wherever the session layer decides.
///
/// [accessToken] is the Supabase Auth JWT of the signed-in user.
class AccountKeyService {
  final AccountKeyRemote _remote;
  final AccountKeyCrypto _crypto;

  AccountKeyService(this._remote, {AccountKeyCrypto? crypto}) : _crypto = crypto ?? AccountKeyCrypto();

  /// Generates the data key of a new account, wraps it with [password] and
  /// creates the row. Throws [AccountKeyConflictException] when the account
  /// already has a key: the caller must [unlock] instead, never replace it.
  Future<Uint8List> createForNewAccount(String password, String accessToken) async {
    final dataKey = _crypto.newDataKey();
    final wrap = await _crypto.wrapWithPassword(dataKey, password);
    await _remote.insert(wrap.toEnvelope(), accessToken);
    return dataKey;
  }

  /// The stored row, or null when the account has no key yet. Lets the
  /// caller look at `needsRewrap` and `hasRecoveryKey`.
  Future<AccountKeyEnvelope?> fetchEnvelope(String accessToken) => _remote.fetch(accessToken);

  /// Opens the data key with [password]. Throws
  /// [AccountKeyNotFoundException] when the account has no key and
  /// [WrongPasswordException] (with `needsRewrap` set from the row) when the
  /// password does not open it.
  Future<Uint8List> unlock(String password, String accessToken) async {
    final envelope = await _require(accessToken);
    return _crypto.unwrapWithPassword(envelope, password);
  }

  /// Wraps [dataKey] with [newPassword] and saves it, clearing
  /// `needs_rewrap`. Call it BEFORE changing the Auth password: if this
  /// fails the old password still opens the key. If the Auth change fails
  /// afterwards, call it again with the old password so both match.
  ///
  /// Also the second half of the `needs_rewrap` flow: a device that holds
  /// the key calls it with the password set by the reset.
  Future<void> changePassword(Uint8List dataKey, String newPassword, String accessToken) async {
    final wrap = await _crypto.rewrap(dataKey, newPassword);
    await _remote.patch(wrap.toJson(), accessToken);
  }

  /// Flags the row after a password reset done without the data key, so a
  /// device that holds it wraps it again with the new password.
  Future<void> markNeedsRewrap(String accessToken) async {
    await _remote.patch({'needs_rewrap': true}, accessToken);
  }

  /// Creates a recovery key, stores the data key wrapped with it and returns
  /// it for the user to write down. Replaces any previous recovery key, which
  /// stops working.
  Future<String> setRecoveryKey(Uint8List dataKey, String accessToken) async {
    final recoveryKey = _crypto.generateRecoveryKey();
    final wrap = await _crypto.wrapWithRecoveryKey(dataKey, recoveryKey);
    await _remote.patch(wrap.toJson(), accessToken);
    return recoveryKey;
  }

  /// Opens the data key with the recovery key, typed in any format. Throws
  /// [NoRecoveryKeyException], [InvalidRecoveryKeyFormatException] or
  /// [WrongRecoveryKeyException]. The caller then wraps the key with the
  /// current password through [changePassword].
  Future<Uint8List> unlockWithRecoveryKey(String recoveryKey, String accessToken) async {
    final envelope = await _require(accessToken);
    return _crypto.unwrapWithRecoveryKey(envelope, recoveryKey);
  }

  /// Deletes the account's key row, so [createForNewAccount] can make a new
  /// one. Everything encrypted under the old key becomes unreadable: only
  /// for "start from scratch", after deleting those records.
  Future<void> deleteKey(String accessToken) => _remote.delete(accessToken);

  Future<AccountKeyEnvelope> _require(String accessToken) async {
    final envelope = await _remote.fetch(accessToken);
    if (envelope == null) throw const AccountKeyNotFoundException();
    return envelope;
  }
}
