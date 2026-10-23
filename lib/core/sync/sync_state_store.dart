import 'package:hive_ce_flutter/hive_flutter.dart';

/// What this device remembers between syncs, in its own encrypted box:
/// the fingerprint of every record as last synced (to spot local edits and
/// deletions), the pull cursor, and whether the device has just been linked
/// to an existing sync set.
class SyncStateStore {
  static const _cursorKey = 'cursor';
  static const _joiningKey = 'joining';
  static const _lastSyncKey = 'lastSync';
  static const _hashesPrefix = 'hashes:';

  final Box<dynamic> _box;

  SyncStateStore(this._box);

  /// Server `updated_at` of the newest row already pulled; null before the
  /// first sync.
  DateTime? get cursor => _parse(_box.get(_cursorKey));

  Future<void> setCursor(DateTime value) => _box.put(_cursorKey, value.toUtc().toIso8601String());

  /// A device linked to an existing sync set lets the server win its first
  /// sync, so a fresh install's empty profile can't overwrite real data.
  bool get joining => _box.get(_joiningKey) == true;

  Future<void> setJoining(bool value) => _box.put(_joiningKey, value);

  DateTime? get lastSync => _parse(_box.get(_lastSyncKey));

  Future<void> setLastSync(DateTime value) => _box.put(_lastSyncKey, value.toUtc().toIso8601String());

  /// identity → fingerprint of each record of [boxName] as last synced.
  Map<String, String> hashes(String boxName) {
    final raw = _box.get('$_hashesPrefix$boxName');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> setHashes(String boxName, Map<String, String> value) => _box.put('$_hashesPrefix$boxName', value);

  /// Forgets everything, so the next sync starts over (used when sync is
  /// turned off or the device is linked to another set).
  Future<void> reset() => _box.clear();

  static DateTime? _parse(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
}
