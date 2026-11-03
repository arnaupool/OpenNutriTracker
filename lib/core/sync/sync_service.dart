import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';

enum SyncPhase { off, idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final DateTime? lastSync;
  final Object? error;

  const SyncStatus(this.phase, {this.lastSync, this.error});
}

/// The active profile has an account but cannot sync with it now: signed
/// out, or the key needs the new password ([AccountSessionService.status]).
/// Reported as the [SyncStatus.error] of a [SyncPhase.error].
class AccountSyncUnavailableException implements Exception {
  final AccountStatus status;

  const AccountSyncUnavailableException(this.status);

  @override
  String toString() => 'AccountSyncUnavailableException: ${status.name}';
}

/// Access token source for one account's requests.
typedef AccessTokenSource = Future<String> Function({bool forceRefresh});

sealed class _Mode {}

class _Off extends _Mode {}

class _Unavailable extends _Mode {
  final AccountStatus status;

  _Unavailable(this.status);
}

class _Account extends _Mode {
  final String profileId;
  final AccountLink link;
  final Uint8List key;

  _Account(this.profileId, this.link, this.key);
}

/// Decides when to sync and reports how it went (FAS-01, B6): on app start,
/// when the app comes back to the foreground, a few seconds after any local
/// change, every few minutes while open, and on demand from Settings.
///
/// Always for the active profile ([ProfileScope.activeId]), whose boxes are
/// open:
/// - A profile with an account syncs through it (`account_records`, the
///   account's access token and data key) when the account is
///   [AccountStatus.ready]; otherwise the status is an error with
///   [AccountSyncUnavailableException] and nothing is sent.
/// - A profile without an account does not sync. This includes a profile
///   that was paired with the removed QR-code sync: it keeps its data and
///   syncs again once it is linked to an account.
class SyncService with WidgetsBindingObserver {
  static const Duration changeDebounce = Duration(seconds: 4);
  static const Duration periodic = Duration(minutes: 2);

  final _log = Logger('SyncService');
  final SyncEngine _engine;
  final AccountSessionService _accounts;
  final Box<dynamic> _stateBox;
  final List<SyncedBox<dynamic>> _boxes;
  final SyncRemote Function(String userId, AccessTokenSource accessToken) _accountRemote;
  final String Function() _activeProfile;

  /// Called after a sync wrote downloaded records into local boxes, to
  /// recompute derived data and refresh the screens.
  final Future<void> Function(List<SyncAppliedChange> applied) onApplied;

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus(SyncPhase.off));

  final List<StreamSubscription<dynamic>> _watchers = [];
  Timer? _debounce;
  Timer? _periodic;
  bool _started = false;
  Future<SyncResult?>? _running;
  bool _again = false;

  /// Set while [startFresh] replaces the key: automatic syncs wait.
  bool _exclusive = false;

  SyncService({
    required SyncEngine engine,
    required AccountSessionService accounts,
    required Box<dynamic> stateBox,
    required List<SyncedBox<dynamic>> boxes,
    required SyncRemote Function(String userId, AccessTokenSource accessToken) accountRemote,
    required this.onApplied,
    String Function()? activeProfile,
  }) : _engine = engine,
       _accounts = accounts,
       _stateBox = stateBox,
       _boxes = boxes,
       _accountRemote = accountRemote,
       _activeProfile = activeProfile ?? (() => ProfileScope.activeId);

  /// Starts the automatic triggers. Safe to call more than once; does
  /// nothing visible while sync is off on this device.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    for (final b in _boxes) {
      _watchers.add(
        b.box.watch().listen((_) {
          if (_running != null) return;
          _debounce?.cancel();
          _debounce = Timer(changeDebounce, () => unawaited(syncNow()));
        }),
      );
    }
    _periodic = Timer.periodic(periodic, (_) => unawaited(syncNow()));
    await _refreshPhase();
    unawaited(syncNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  /// Runs one sync, or joins the one in progress and queues another so
  /// changes made meanwhile aren't missed. Returns null when nothing was
  /// synced (sync off, account not ready, an error: see [status]).
  Future<SyncResult?> syncNow() async {
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _run();
    _running = run;
    try {
      return await run;
    } finally {
      _running = null;
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  // Account sign-out safety (C8)

  /// Whether the active profile [profileId] holds local changes its account
  /// does not have yet. False for a profile without an account. Local only;
  /// throws [StateError] for a profile that is not the active one (its
  /// boxes are closed: switch to it first).
  Future<bool> hasPendingChanges(String profileId) async {
    _requireActive(profileId);
    final link = await _accounts.link(profileId);
    if (link == null) return false;
    final state = SyncStateStore.account(_stateBox, link.userId);
    final key = await _accounts.dataKey(profileId);
    if (key != null && state.keyId != null && state.keyId != SyncEngine.keyId(key)) {
      // Built with an older key: everything goes up again.
      return _boxes.any((b) => b.keysByIdentity().isNotEmpty);
    }
    return _engine.hasLocalChanges(state);
  }

  /// Syncs the active profile [profileId] with its account and returns true
  /// only if afterwards everything local is on the server. C8 calls it
  /// before signing out; false means signing out would lose data. False for
  /// a profile without an account. Throws [StateError] for a profile that
  /// is not the active one.
  Future<bool> syncBeforeSignOut(String profileId) async {
    _requireActive(profileId);
    if (await _accounts.link(profileId) == null) return false;
    // A fresh run, not one that started before the latest changes.
    while (_running != null) {
      await _running;
    }
    final result = await syncNow();
    if (result == null) return false;
    return !await hasPendingChanges(profileId);
  }

  /// "Start from scratch" (C7/C8), after a password reset when no device
  /// holds the old data key and there is no recovery key: deletes the
  /// account's records and key row, creates a new key wrapped with
  /// [password], stores it, the session and the link for [profileId], and
  /// pushes the profile's local data. See
  /// [AccountSessionService.startFresh] for [email] and the errors.
  ///
  /// Returns true when the local data is on the server; false when it is
  /// not yet (an error, or [profileId] is not the active profile): it goes
  /// up with the next sync of that profile.
  Future<bool> startFresh(String profileId, String password, {String? email}) async {
    _exclusive = true;
    try {
      while (_running != null) {
        await _running;
      }
      final key = await _accounts.startFresh(
        profileId,
        password,
        email: email,
        deleteRecords: (token, userId) =>
            _accountRemote(userId, ({bool forceRefresh = false}) async => token).deleteAll(),
      );
      final link = (await _accounts.link(profileId))!;
      try {
        // Right away, so a device still holding the old key stops writing.
        await _engine.writeKeyCheck(_accountRemote(link.userId, _tokenSource(profileId)), key);
      } on Object catch (e) {
        _log.warning('start from scratch: key check not written yet', e);
      }
    } finally {
      _exclusive = false;
    }
    if (profileId != _activeProfile()) return false;
    return syncBeforeSignOut(profileId);
  }

  /// Stops the automatic triggers (tests, and before a restore replaces the
  /// boxes wholesale).
  Future<void> stop() async {
    _debounce?.cancel();
    _periodic?.cancel();
    for (final w in _watchers) {
      await w.cancel();
    }
    _watchers.clear();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  // Internals

  Future<SyncResult?> _run() async {
    if (_exclusive) return null;
    try {
      final mode = await _resolve();
      switch (mode) {
        case _Off():
          status.value = const SyncStatus(SyncPhase.off);
          return null;
        case _Unavailable(status: final accountStatus):
          status.value = SyncStatus(SyncPhase.error, error: AccountSyncUnavailableException(accountStatus));
          return null;
        case _Account():
          return await _runAccount(mode);
      }
    } catch (e, st) {
      _log.warning('Sync failed', e, st);
      status.value = SyncStatus(SyncPhase.error, lastSync: status.value.lastSync, error: e);
      return null;
    }
  }

  Future<SyncResult> _runAccount(_Account mode) async {
    final state = await _accountState(mode.link.userId, mode.key);
    status.value = SyncStatus(SyncPhase.syncing, lastSync: state.lastSync);
    final result = await _engine.sync(
      SyncTarget(remote: _accountRemote(mode.link.userId, _tokenSource(mode.profileId)), state: state, key: mode.key),
    );
    if (result.applied.isNotEmpty) await onApplied(result.applied);
    status.value = SyncStatus(SyncPhase.idle, lastSync: state.lastSync);
    _log.fine('Account sync: pulled ${result.pulled}, pushed ${result.pushed}, unreadable ${result.unreadable}');
    return result;
  }

  Future<_Mode> _resolve() async {
    final profileId = _activeProfile();
    final link = await _accounts.link(profileId);
    if (link != null) {
      final accountStatus = await _accounts.status(profileId);
      if (accountStatus != AccountStatus.ready) return _Unavailable(accountStatus);
      final key = await _accounts.dataKey(profileId);
      if (key == null) return _Unavailable(AccountStatus.signedOut);
      return _Account(profileId, link, key);
    }
    return _Off();
  }

  /// The account state for [key]; a state built with another key starts
  /// over, so every local record goes up again.
  Future<SyncStateStore> _accountState(String userId, Uint8List key) async {
    final state = SyncStateStore.account(_stateBox, userId);
    final id = SyncEngine.keyId(key);
    if (state.keyId != id) {
      await state.reset();
      await state.setKeyId(id);
    }
    return state;
  }

  AccessTokenSource _tokenSource(String profileId) =>
      ({bool forceRefresh = false}) => _accounts.accessToken(profileId, forceRefresh: forceRefresh);

  void _requireActive(String profileId) {
    if (profileId != _activeProfile()) {
      throw StateError('Only the active profile can be synced; switch to $profileId first');
    }
  }

  Future<void> _refreshPhase() async {
    final link = await _accounts.link(_activeProfile());
    if (link != null) {
      status.value = SyncStatus(SyncPhase.idle, lastSync: SyncStateStore.account(_stateBox, link.userId).lastSync);
      return;
    }
    status.value = const SyncStatus(SyncPhase.off);
  }
}
