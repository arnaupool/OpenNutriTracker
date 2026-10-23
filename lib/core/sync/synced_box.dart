import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// One Hive box taking part in sync, and how its records are identified.
///
/// Several boxes use auto-increment int keys (`box.add`), and key 5 on the
/// phone is not key 5 on the desktop, so records are matched across devices
/// by [identityOf], a value the record carries itself (its id, its day, its
/// name). [naturalKey] says whether that identity is also the Hive key; if
/// not, an incoming record replaces the local one with the same identity, or
/// is appended.
class SyncedBox<T> {
  final String name;
  final Box<T> box;
  final String? Function(T value, dynamic hiveKey) identityOf;
  final Map<String, dynamic> Function(T value) toJson;
  final T Function(Map<String, dynamic> json) fromJson;
  final bool naturalKey;

  const SyncedBox({
    required this.name,
    required this.box,
    required this.identityOf,
    required this.toJson,
    required this.fromJson,
    this.naturalKey = false,
  });

  String encode(T value) => jsonEncode(toJson(value));

  T decode(String json) => fromJson(jsonDecode(json) as Map<String, dynamic>);

  /// identity → Hive key of every record that has an identity.
  Map<String, dynamic> keysByIdentity() {
    final result = <String, dynamic>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (value == null) continue;
      final identity = identityOf(value, key);
      if (identity != null) result[identity] = key;
    }
    return result;
  }

  Future<void> put(String identity, T value, Map<String, dynamic> index) async {
    final existingKey = index[identity];
    if (existingKey != null) {
      await box.put(existingKey, value);
    } else if (naturalKey) {
      await box.put(identity, value);
      index[identity] = identity;
    } else {
      index[identity] = await box.add(value);
    }
  }

  Future<void> delete(String identity, Map<String, dynamic> index) async {
    final existingKey = index.remove(identity);
    if (existingKey != null) await box.delete(existingKey);
  }
}
