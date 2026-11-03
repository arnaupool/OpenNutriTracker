import 'package:hive_ce_flutter/hive_flutter.dart';

/// What this device remembers between syncs, in its own encrypted box:
/// the fingerprint of every record as last synced (to spot local edits and
/// deletions) and the pull cursor.
///
/// One box can hold the states of several accounts ([SyncStateStore.account],
/// keys under `acct:<user id>/`). A state also remembers which data key it
/// was built with ([keyId]): a new key (start from scratch) makes every
/// record pending again.
class SyncStateStore {
  static const _cursorKey = 'cursor';
  static const _lastSyncKey = 'lastSync';
  static const _keyIdKey = 'keyId';
  static const _hashesPrefix = 'hashes:';
  static const _accountPrefix = 'acct:';

  final Box<dynamic> _box;
  final String _prefix;

  /// The state of [userId]'s account in [box].
  SyncStateStore.account(this._box, String userId) : _prefix = '$_accountPrefix$userId/';

  /// Server `updated_at` of the newest row already pulled; null before the
  /// first sync.
  DateTime? get cursor => _parse(_box.get('$_prefix$_cursorKey'));

  Future<void> setCursor(DateTime value) => _box.put('$_prefix$_cursorKey', value.toUtc().toIso8601String());

  /// When this state last completed a sync; null before the first one.
  DateTime? get lastSync => _parse(_box.get('$_prefix$_lastSyncKey'));

  Future<void> setLastSync(DateTime value) => _box.put('$_prefix$_lastSyncKey', value.toUtc().toIso8601String());

  /// Opaque id of the data key this state was built with (account states).
  String? get keyId => _box.get('$_prefix$_keyIdKey') as String?;

  Future<void> setKeyId(String value) => _box.put('$_prefix$_keyIdKey', value);

  /// identity → fingerprint of each record of [boxName] as last synced.
  Map<String, String> hashes(String boxName) {
    final raw = _box.get('$_prefix$_hashesPrefix$boxName');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> setHashes(String boxName, Map<String, String> value) =>
      _box.put('$_prefix$_hashesPrefix$boxName', value);

  /// Forgets this state, so the next sync starts over (new account key). Leaves the other states in the
  /// box alone.
  Future<void> reset() async {
    final mine = _box.keys.map((k) => k.toString()).where(_owns).toList();
    await _box.deleteAll(mine);
  }

  bool _owns(String key) => key.startsWith(_prefix);

  static DateTime? _parse(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
}
