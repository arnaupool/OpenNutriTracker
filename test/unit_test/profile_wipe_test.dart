import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        value == null ? values.remove(key) : values[key!] = value;
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late Directory dir;
  late _MemoryStorage storage;
  late ProfileStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wipe');
    Hive.init(dir.path);
    storage = _MemoryStorage();
    store = ProfileStore(storage: storage);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('wipeDefault deletes every box and secret and leaves an empty local default profile', () async {
    for (final name in HiveDBProvider.profileBoxNames) {
      final box = await Hive.openBox<dynamic>(name);
      await box.put('k', 'v');
    }
    await Hive.close();
    storage.values['AccountSession'] = 'session';
    storage.values['AccountDataKey'] = 'key';
    storage.values['AccountSession.other'] = 'keep';
    await store.setAccount(AppProfile.defaultId, const AccountLink(userId: 'u1', email: 'me@example.org'));
    final other = await store.add('Other');

    await store.wipeDefault();

    for (final name in HiveDBProvider.profileBoxNames) {
      expect(await Hive.boxExists(name), isFalse, reason: name);
    }
    expect(storage.values.containsKey('AccountSession'), isFalse);
    expect(storage.values.containsKey('AccountDataKey'), isFalse);
    expect(storage.values['AccountSession.other'], 'keep');
    final profiles = await store.all();
    final def = profiles.firstWhere((p) => p.isDefault);
    expect(def.isLocal, isTrue);
    expect(profiles.any((p) => p.id == other.id), isTrue);
  });
}
