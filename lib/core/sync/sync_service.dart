import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';

enum SyncPhase { off, idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final DateTime? lastSync;
  final Object? error;

  const SyncStatus(this.phase, {this.lastSync, this.error});
}

/// Decides when to sync and reports how it went (FAS-01): on app start, when
/// the app comes back to the foreground, a few seconds after any local
/// change, every few minutes while open (so the desktop sees phone entries),
/// and on demand from Settings.
class SyncService with WidgetsBindingObserver {
  static const Duration changeDebounce = Duration(seconds: 4);
  static const Duration periodic = Duration(minutes: 2);

  final _log = Logger('SyncService');
  final SyncEngine _engine;
  final SyncKeyService _keys;
  final SyncStateStore _state;
  final List<SyncedBox<dynamic>> _boxes;

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

  SyncService(this._engine, this._keys, this._state, this._boxes, {required this.onApplied});

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
  /// changes made meanwhile aren't missed.
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

  Future<SyncResult?> _run() async {
    final pairing = await _keys.read();
    if (pairing == null) {
      status.value = const SyncStatus(SyncPhase.off);
      return null;
    }
    status.value = SyncStatus(SyncPhase.syncing, lastSync: _state.lastSync);
    try {
      final result = await _engine.sync(pairing);
      if (result.applied.isNotEmpty) await onApplied(result.applied);
      status.value = SyncStatus(SyncPhase.idle, lastSync: _state.lastSync);
      _log.fine('Sync done: pulled ${result.pulled}, pushed ${result.pushed}, unreadable ${result.unreadable}');
      return result;
    } catch (e, st) {
      _log.warning('Sync failed', e, st);
      status.value = SyncStatus(SyncPhase.error, lastSync: _state.lastSync, error: e);
      return null;
    }
  }

  /// Turns sync on as the device whose data seeds the set.
  Future<SyncPairing> enableAsOwner() async {
    final pairing = await _keys.enable();
    await _state.reset();
    await _refreshPhase();
    _kick();
    return pairing;
  }

  /// Links this device to an existing set: the server's copy wins on the
  /// first sync, so this device's records only fill gaps.
  Future<void> join(SyncPairing pairing) async {
    await _keys.store(pairing);
    await _state.reset();
    await _state.setJoining(true);
    await _refreshPhase();
    _kick();
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

  Future<void> disable() async {
    await _keys.disable();
    await _state.reset();
    status.value = const SyncStatus(SyncPhase.off);
  }

  /// Syncs now, starting the automatic triggers first if the app was
  /// launched before sync was turned on (for example, right after onboarding).
  void _kick() {
    if (_started) {
      unawaited(syncNow());
    } else {
      unawaited(start());
    }
  }

  Future<void> _refreshPhase() async {
    final enabled = await _keys.isEnabled();
    status.value = enabled ? SyncStatus(SyncPhase.idle, lastSync: _state.lastSync) : const SyncStatus(SyncPhase.off);
  }
}
