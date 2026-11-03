import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// The account a profile belongs to (docs/plan-cuentas.md, decision 1).
class AccountLink {
  /// Supabase Auth user id.
  final String userId;

  /// Normalized (trimmed, lower-case) email, shown in the account picker.
  final String email;

  const AccountLink({required this.userId, required this.email});

  Map<String, dynamic> toJson() => {'userId': userId, 'email': email};

  factory AccountLink.fromJson(Map<String, dynamic> json) =>
      AccountLink(userId: json['userId'] as String, email: json['email'] as String);

  @override
  bool operator ==(Object other) => other is AccountLink && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}

class AppProfile {
  /// The profile every install starts with. It keeps the original box and
  /// key names, so existing data needs no migration.
  static const String defaultId = 'default';

  final String id;
  final String name;

  /// The account this profile belongs to, or null for a local profile (no
  /// account, no sync). It stays set after signing out, so the profile's
  /// data is never attached to a different account.
  final AccountLink? account;

  const AppProfile(this.id, this.name, {this.account});

  bool get isDefault => id == defaultId;

  bool get isLocal => account == null;

  AppProfile withName(String name) => AppProfile(id, name, account: account);

  AppProfile withAccount(AccountLink? account) => AppProfile(id, name, account: account);

  /// Profiles stored before accounts existed have no `account` key and read
  /// back as local profiles.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, if (account != null) 'account': account!.toJson()};

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    return AppProfile(
      json['id'] as String,
      json['name'] as String,
      account: account is Map<String, dynamic> ? AccountLink.fromJson(account) : null,
    );
  }
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
  static String secret(String key) => secretFor(key, _activeId);

  /// [secret] for any profile, active or not: account sessions of every
  /// profile live side by side.
  static String secretFor(String key, String profileId) => profileId == AppProfile.defaultId ? key : '$key.$profileId';
}

/// The list of profiles and which one is active, in secure storage (not in
/// a profile's own boxes, which only open once a profile is chosen).
class ProfileStore {
  static const _profilesKey = 'Profiles';
  static const _activeKey = 'ActiveProfile';

  /// Per-profile secrets deleted with the profile.
  static const secretKeys = ['CloudBackupToken', 'SyncKey', 'AccountSession', 'AccountDataKey'];

  final FlutterSecureStorage _storage;

  ProfileStore({FlutterSecureStorage? storage}) : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  Future<List<AppProfile>> all() async {
    final raw = await _storage.read(key: _profilesKey);
    final list = raw == null
        ? <AppProfile>[]
        : (jsonDecode(raw) as List<dynamic>).map((e) => AppProfile.fromJson(e as Map<String, dynamic>)).toList();
    if (!list.any((p) => p.isDefault)) list.insert(0, const AppProfile(AppProfile.defaultId, ''));
    return list;
  }

  Future<AppProfile?> byId(String id) async {
    for (final p in await all()) {
      if (p.id == id) return p;
    }
    return null;
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
    await _save([for (final p in await all()) p.id == id ? p.withName(name.trim()) : p]);
  }

  /// Links a profile to an account, or unlinks it with null. Only
  /// `AccountSessionService` should call this.
  Future<void> setAccount(String id, AccountLink? account) async {
    final profiles = await all();
    if (!profiles.any((p) => p.id == id)) throw ArgumentError.value(id, 'id', 'unknown profile');
    await _save([for (final p in profiles) p.id == id ? p.withAccount(account) : p]);
  }

  /// Deletes a profile that is not the active one, with its boxes and its
  /// secrets (legacy pairing tokens, account session and data key).
  Future<void> remove(String id) async {
    if (id == AppProfile.defaultId) throw ArgumentError('The default profile cannot be removed');
    if (id == ProfileScope.activeId) throw ArgumentError('Switch to another profile first');
    await _deleteData(id);
    await _save([
      for (final p in await all())
        if (p.id != id) p,
    ]);
  }

  /// Signing out of the default profile (which cannot be removed): deletes
  /// its boxes and secrets and leaves an empty local profile, so the app
  /// starts at the first-run choice. Hive must be closed (the app reloads
  /// afterwards), as the boxes are deleted from disk.
  Future<void> wipeDefault() async {
    await _deleteData(AppProfile.defaultId);
    await _save([for (final p in await all()) p.isDefault ? const AppProfile(AppProfile.defaultId, '') : p]);
  }

  Future<void> _deleteData(String id) async {
    for (final name in HiveDBProvider.profileBoxNames) {
      await Hive.deleteBoxFromDisk(id == AppProfile.defaultId ? name : 'p_${id}_$name');
    }
    for (final key in secretKeys) {
      await _storage.delete(key: ProfileScope.secretFor(key, id));
    }
  }

  Future<void> _save(List<AppProfile> profiles) =>
      _storage.write(key: _profilesKey, value: jsonEncode([for (final p in profiles) p.toJson()]));
}
