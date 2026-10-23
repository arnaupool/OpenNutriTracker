import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

class AppProfile {
  /// The profile every install starts with. It keeps the original box and
  /// key names, so existing data needs no migration.
  static const String defaultId = 'default';

  final String id;
  final String name;

  const AppProfile(this.id, this.name);

  bool get isDefault => id == defaultId;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory AppProfile.fromJson(Map<String, dynamic> json) => AppProfile(json['id'] as String, json['name'] as String);
}

/// Which profile this run of the app belongs to. Everything that stores data
/// asks it for names: Hive boxes and secure-storage keys of other profiles
/// get a prefix or suffix, so profiles never see each other's diary, goals,
/// photos or sync code.
class ProfileScope {
  static String _activeId = AppProfile.defaultId;

  static String get activeId => _activeId;

  static void activate(String id) => _activeId = id;

  /// Physical Hive box name for a logical one.
  static String box(String logicalName) =>
      _activeId == AppProfile.defaultId ? logicalName : 'p_${_activeId}_$logicalName';

  /// Secure-storage key for a per-profile secret.
  static String secret(String key) => _activeId == AppProfile.defaultId ? key : '$key.$_activeId';
}

/// The list of profiles and which one is active, in secure storage (not in
/// a profile's own boxes, which only open once a profile is chosen).
class ProfileStore {
  static const _profilesKey = 'Profiles';
  static const _activeKey = 'ActiveProfile';

  final _storage = SecureAppStorageProvider.secureAppStorage;

  Future<List<AppProfile>> all() async {
    final raw = await _storage.read(key: _profilesKey);
    final list = raw == null
        ? <AppProfile>[]
        : (jsonDecode(raw) as List<dynamic>).map((e) => AppProfile.fromJson(e as Map<String, dynamic>)).toList();
    if (!list.any((p) => p.isDefault)) list.insert(0, const AppProfile(AppProfile.defaultId, ''));
    return list;
  }

  Future<String> activeId() async {
    final id = await _storage.read(key: _activeKey);
    if (id == null) return AppProfile.defaultId;
    final known = await all();
    return known.any((p) => p.id == id) ? id : AppProfile.defaultId;
  }

  Future<void> setActive(String id) => _storage.write(key: _activeKey, value: id);

  Future<AppProfile> add(String name) async {
    final profile = AppProfile(IdGenerator.getUniqueID().replaceAll(RegExp('[^A-Za-z0-9]'), ''), name.trim());
    await _save([...await all(), profile]);
    return profile;
  }

  Future<void> rename(String id, String name) async {
    await _save([for (final p in await all()) p.id == id ? AppProfile(id, name.trim()) : p]);
  }

  /// Deletes a profile that is not the active one, with its boxes and its
  /// secrets (backup token, sync key).
  Future<void> remove(String id) async {
    if (id == AppProfile.defaultId) throw ArgumentError('The default profile cannot be removed');
    if (id == ProfileScope.activeId) throw ArgumentError('Switch to another profile first');
    for (final name in HiveDBProvider.profileBoxNames) {
      await Hive.deleteBoxFromDisk('p_${id}_$name');
    }
    for (final key in const ['CloudBackupToken', 'SyncKey']) {
      await _storage.delete(key: '$key.$id');
    }
    await _save([for (final p in await all()) if (p.id != id) p]);
  }

  Future<void> _save(List<AppProfile> profiles) =>
      _storage.write(key: _profilesKey, value: jsonEncode([for (final p in profiles) p.toJson()]));
}
