import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// The user's own Open Food Facts account, used to sign product
/// contributions. Kept in the platform keystore next to the Hive key, never
/// in Hive, so it is not part of backups or exports.
class OffCredentials {
  final String userId;
  final String password;

  const OffCredentials({required this.userId, required this.password});
}

class OffAccountDataSource {
  static const _userIdKey = 'OffContributionUserId';
  static const _passwordKey = 'OffContributionPassword';

  final FlutterSecureStorage _storage;

  OffAccountDataSource({FlutterSecureStorage? storage})
      : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  Future<OffCredentials?> read() async {
    final userId = await _storage.read(key: _userIdKey);
    final password = await _storage.read(key: _passwordKey);
    if (userId == null || userId.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return OffCredentials(userId: userId, password: password);
  }

  Future<void> save(OffCredentials credentials) async {
    await _storage.write(key: _userIdKey, value: credentials.userId.trim());
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _passwordKey);
  }
}
