import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:opennutritracker/core/sync/sync_crypto.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/sync/synced_box.dart';

/// A record that changed on this device since the last sync.
class _LocalChange {
  final SyncedBox<dynamic> box;
  final String identity;

  /// Record JSON; null when the record was deleted.
  final String? json;
  final DateTime modifiedAt;

  _LocalChange(this.box, this.identity, this.json, this.modifiedAt);
}

/// A record written into a local box by a pull: its previous and new value
/// (either may be null), so callers can refresh derived data such as the
/// daily totals.
class SyncAppliedChange {
  final String box;
  final Object? before;
  final Object? after;

  const SyncAppliedChange(this.box, this.before, this.after);
}

class SyncResult {
  final int pulled;
  final int pushed;
  final int unreadable;
  final List<SyncAppliedChange> applied;

  const SyncResult({required this.pulled, required this.pushed, required this.unreadable, required this.applied});
}

/// The account's records are encrypted with another data key than the one
/// this device holds (the account started from scratch elsewhere). Nothing
/// was pulled or pushed; the profile has to sign in again.
class SyncKeyMismatchException implements Exception {
  const SyncKeyMismatchException();

  @override
  String toString() => 'SyncKeyMismatchException: the account data key changed';
}

/// One account's rows to sync with: where ([remote]), what this device
/// remembers about it ([state]) and the key that encrypts it.
class SyncTarget {
  final SyncRemote remote;
  final SyncStateStore state;
  final Uint8List key;

  const SyncTarget({required this.remote, required this.state, required this.key});
}

/// Record-level, two-way sync of the Hive boxes in [boxes] (FAS-01, B6).
///
/// 1. Compares every record's fingerprint with the one stored after the
///    previous sync to find local additions, edits and deletions.
/// 2. Pulls rows changed on the server since the cursor and applies them,
///    unless this device holds a newer local edit of the same record (last
///    write wins on `modified_at`).
/// 3. Pushes the local changes, encrypted. The server also refuses older
///    versions, so a device that was offline can't overwrite newer data.
///
/// [sync] returns only after every push succeeded; any failure throws and
/// leaves the stored state as it was, so the next sync retries the same
/// changes.
class SyncEngine {
  /// Pulls re-read a short window before the cursor: a write that started
  /// before another device's pull but committed after it would otherwise be
  /// skipped. Re-reading a row already applied is a no-op.
  static const Duration cursorOverlap = Duration(minutes: 2);
  static const int pageSize = 500;
  static const int pushBatchSize = 200;

  /// `modified_at` of local records on the first sync with an account: older
  /// than anything real, so the account's copy wins.
  static final DateTime joiningEpoch = DateTime.utc(2000);

  /// The row that shows which data key encrypts an account's records. Its
  /// names are plain (they reveal nothing); its payload is [_keyCheckText]
  /// encrypted with the data key.
  static const String keyCheckBox = 'key-check';
  static const String keyCheckId = 'v1';
  static const String _keyCheckText = 'ont-key-check-v1';

  final _log = Logger('SyncEngine');
  final List<SyncedBox<dynamic>> boxes;

  SyncEngine({required this.boxes});

  /// Opaque, stable id of a data key, so a state can tell that the key
  /// changed without storing the key.
  static String keyId(Uint8List key) => SyncCrypto(key).opaqueId('sync-state-key-id');

  /// Server row id of a record. The NUL separator is part of the format:
  /// changing it would orphan every row already on a server.
  static String _rowId(SyncCrypto crypto, String box, String identity) => crypto.opaqueId('$box\u0000$identity');

  Future<SyncResult> sync(SyncTarget target, {DateTime? now}) async {
    final clock = (now ?? DateTime.now()).toUtc();
    final remote = target.remote;
    final state = target.state;
    final crypto = SyncCrypto(target.key);
    await _checkKey(remote, crypto, clock);

    // First sync with an account: the server's copy wins, local-only
    // records go up.
    final firstAccountSync = state.lastSync == null;
    DateTime stamp() => firstAccountSync ? joiningEpoch : clock;

    // The server only ever sees keyed hashes of box names and record ids;
    // the real identity travels inside the encrypted payload.
    final byOpaqueName = {for (final b in boxes) crypto.opaqueId('box:${b.name}'): b};
    String rowId(SyncedBox<dynamic> b, String identity) => _rowId(crypto, b.name, identity);
    final hashes = {for (final b in boxes) b.name: state.hashes(b.name)};
    final indexes = {for (final b in boxes) b.name: b.keysByIdentity()};

    // 1. Local changes since the last sync, keyed by server row id.
    final pending = <String, _LocalChange>{};
    for (final b in boxes) {
      final known = hashes[b.name]!;
      final seen = <String>{};
      for (final entry in indexes[b.name]!.entries) {
        final value = b.box.get(entry.value);
        if (value == null) continue;
        final json = b.encode(value);
        final fingerprint = SyncCrypto.fingerprint(json);
        seen.add(entry.key);
        if (known[entry.key] != fingerprint) {
          pending[rowId(b, entry.key)] = _LocalChange(b, entry.key, json, stamp());
        }
      }
      for (final identity in known.keys) {
        if (!seen.contains(identity)) {
          pending[rowId(b, identity)] = _LocalChange(b, identity, null, clock);
        }
      }
    }

    // 2. Pull and apply.
    var pulled = 0;
    var unreadable = 0;
    final applied = <SyncAppliedChange>[];
    DateTime? newest = state.cursor;
    final since = newest?.subtract(cursorOverlap);
    SyncRow? after;
    while (true) {
      final rows = await remote.pull(since: since, after: after, limit: pageSize);
      for (final row in rows) {
        if (row.updatedAt != null && (newest == null || row.updatedAt!.isAfter(newest))) {
          newest = row.updatedAt;
        }
        final b = byOpaqueName[row.box];
        if (b == null) continue;
        final local = pending[row.id];
        if (local != null && local.modifiedAt.isAfter(row.modifiedAt)) continue;

        final String identity;
        final Object? value;
        final String? fingerprint;
        try {
          final envelope = jsonDecode(crypto.decrypt(row.payload!)) as Map<String, dynamic>;
          identity = envelope['i'] as String;
          final json = envelope['v'] as String?;
          if (row.deleted || json == null) {
            value = null;
            fingerprint = null;
          } else {
            value = b.decode(json);
            fingerprint = SyncCrypto.fingerprint(b.encode(value));
          }
        } catch (e) {
          // Another key or a corrupt row: leave the local copy alone.
          _log.warning('Unreadable sync row in ${b.name}', e);
          unreadable++;
          continue;
        }
        pending.remove(row.id);
        final index = indexes[b.name]!;
        final known = hashes[b.name]!;
        final existingKey = index[identity];
        final before = existingKey == null ? null : b.box.get(existingKey);
        if (value == null) {
          known.remove(identity);
          if (existingKey == null) continue;
          await b.delete(identity, index);
          applied.add(SyncAppliedChange(b.name, before, null));
          pulled++;
          continue;
        }
        if (existingKey != null && known[identity] == fingerprint) continue;
        if (before != null && SyncCrypto.fingerprint(b.encode(before)) == fingerprint) {
          // Same content on both sides (first sync with an account that
          // already holds this device's data): just remember it.
          known[identity] = fingerprint!;
          continue;
        }
        await b.put(identity, value, index);
        known[identity] = fingerprint!;
        applied.add(SyncAppliedChange(b.name, before, value));
        pulled++;
      }
      if (rows.length < pageSize) break;
      after = rows.last;
    }

    // 3. Push what is still pending.
    final changes = pending.entries.toList();
    for (var i = 0; i < changes.length; i += pushBatchSize) {
      final batch = changes.sublist(i, i + pushBatchSize > changes.length ? changes.length : i + pushBatchSize);
      await remote.push([
        for (final e in batch)
          SyncRow(
            box: crypto.opaqueId('box:${e.value.box.name}'),
            id: e.key,
            payload: crypto.encrypt(jsonEncode({'i': e.value.identity, 'v': e.value.json})),
            modifiedAt: e.value.modifiedAt,
            deleted: e.value.json == null,
          ),
      ]);
      for (final e in batch) {
        final c = e.value;
        final known = hashes[c.box.name]!;
        if (c.json == null) {
          known.remove(c.identity);
        } else {
          known[c.identity] = SyncCrypto.fingerprint(c.json!);
        }
      }
    }

    for (final b in boxes) {
      await state.setHashes(b.name, hashes[b.name]!);
    }
    if (newest != null) await state.setCursor(newest);
    await state.setLastSync(clock);
    return SyncResult(pulled: pulled, pushed: changes.length, unreadable: unreadable, applied: applied);
  }

  /// Whether this device holds changes [state] has not synced: an edit, an
  /// addition or a deletion, or any record at all before the first sync.
  /// Local only, no network.
  bool hasLocalChanges(SyncStateStore state) {
    final synced = state.lastSync != null;
    for (final b in boxes) {
      final known = state.hashes(b.name);
      final index = b.keysByIdentity();
      if (!synced && index.isNotEmpty) return true;
      for (final entry in index.entries) {
        final value = b.box.get(entry.value);
        if (value != null && known[entry.key] != SyncCrypto.fingerprint(b.encode(value))) return true;
      }
      if (known.keys.any((identity) => !index.containsKey(identity))) return true;
    }
    return false;
  }

  /// Writes the key-check row for [key], replacing the one of an older key
  /// (after the account started from scratch).
  Future<void> writeKeyCheck(SyncRemote remote, Uint8List key, {DateTime? now}) =>
      _writeKeyCheck(remote, SyncCrypto(key), (now ?? DateTime.now()).toUtc());

  Future<void> _writeKeyCheck(SyncRemote remote, SyncCrypto crypto, DateTime clock) => remote.push([
    SyncRow(box: keyCheckBox, id: keyCheckId, payload: crypto.encrypt(_keyCheckText), modifiedAt: clock),
  ]);

  /// Refuses to touch an account whose records use another key; creates the
  /// key-check row on an account that has none yet.
  Future<void> _checkKey(SyncRemote remote, SyncCrypto crypto, DateTime clock) async {
    final row = await remote.fetch(keyCheckBox, keyCheckId);
    if (row == null || row.payload == null) {
      await _writeKeyCheck(remote, crypto, clock);
      return;
    }
    try {
      if (crypto.decrypt(row.payload!) == _keyCheckText) return;
    } catch (_) {
      // Another key: refused below.
    }
    throw const SyncKeyMismatchException();
  }
}
