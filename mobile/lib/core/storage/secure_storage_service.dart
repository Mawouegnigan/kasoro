import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encapsule l'accès au stockage sécurisé du device (Keychain sur iOS,
/// Keystore chiffré sur Android). Ne jamais stocker le token autrement
/// (pas de SharedPreferences pour ça).
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'kasoro_access_token';
  static const String _currentUserIdKey = 'kasoro_current_user_id';

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);

  Future<void> saveCurrentUserId(String userId) =>
      _storage.write(key: _currentUserIdKey, value: userId);

  Future<String?> readCurrentUserId() => _storage.read(key: _currentUserIdKey);

  Future<void> clearAll() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _currentUserIdKey);
  }
}

final Provider<FlutterSecureStorage> flutterSecureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final Provider<SecureStorageService> secureStorageServiceProvider =
    Provider<SecureStorageService>((ref) {
  return SecureStorageService(ref.read(flutterSecureStorageProvider));
});
