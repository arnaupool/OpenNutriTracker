import 'package:hive_ce_flutter/hive_flutter.dart';

/// What this device remembers between syncs, in its own encrypted box:
/// the fingerprint of every record as last synced (to spot local edits and
/// deletions), the pull cursor, and whether the device has just been linked
/// to an existing sync set.
///
/// One box holds two independent states: the old pairing token's (keys
/// without prefix, as stored before accounts existed) and the account's
/// ([SyncStateStore.account], keys under `acct:<user id>/`). An account state
/// also remembers which data key it was built with ([keyId]): a new key
/// (start from scratch) makes every record pending again.
class SyncStateStore {
  static const _cursorKey = 'cursor';
  static const _joiningKey = 'joining';
  static const _lastSyncKey = 'lastSync';
  static const _keyIdKey = 'keyId';
  static const _hashesPrefix = 'hashes:';
  static const _accountPrefix = 'acct:';

  final Box<dynamic> _box;
  final String _prefix;

  /// The old pairing-token state.
  SyncStateStore(this._box) : _prefix = '';

  /// The state of [userId]'s account, beside the token state in [box].
  SyncStateStore.account(this._box, String userId) : _prefix = '$_accountPrefix$userId/';

  bool get isAccount => _prefix.isNotEmpty;

  /// Server `updated_at` of the newest row already pulled; null before the
  /// first sync.
  DateTime? get cursor => _parse(_box.get('$_prefix$_cursorKey'));

  Future<void> setCursor(DateTime value) => _box.put('$_prefix$_cursorKey', value.toUtc().toIso8601String());

  /// A device linked to an existing sync set lets the server win its first
  /// sync, so a fresh install's empty profile can't overwrite real data.
  bool get joining => _box.get('$_prefix$_joiningKey') == true;

  Future<void> setJoining(bool value) => _box.put('$_prefix$_joiningKey', value);

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

  /// Forgets this state, so the next sync starts over (sync turned off, the
  /// device linked to another set, a new account key). Leaves the other
  /// states in the box alone.
  Future<void> reset() async {
    final mine = _box.keys.map((k) => k.toString()).where(_owns).toList();
    await _box.deleteAll(mine);
  }

  bool _owns(String key) => isAccount ? key.startsWith(_prefix) : !key.startsWith(_accountPrefix);

  static DateTime? _parse(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
}
