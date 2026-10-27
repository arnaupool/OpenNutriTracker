import 'dart:math';
import 'dart:typed_data';

import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// The random 64-hex identity of this device in the reminders backend (sent
/// as `x-reminder-device`). Generated once, kept in secure storage per profile.
class ReminderDeviceTokenService {
  static const _secureStorageKey = 'ReminderDeviceToken';
  static final RegExp tokenPattern = RegExp(r'^[a-f0-9]{64}$');

  final _secureStorage = SecureAppStorageProvider.secureAppStorage;
  String? _cached;

  Future<String> readOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;
    final key = ProfileScope.secret(_secureStorageKey);
    final stored = await _secureStorage.read(key: key);
    if (stored != null && tokenPattern.hasMatch(stored)) return _cached = stored;
    final token = generate();
    await _secureStorage.write(key: key, value: token);
    return _cached = token;
  }

  /// 32 bytes from a CSPRNG as lowercase hex.
  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
