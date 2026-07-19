import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';

/// Wraps device secure storage (Keychain on iOS, Keystore-backed
/// EncryptedSharedPreferences on Android) for auth token persistence.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  // Without `encryptedSharedPreferences: true`, Android falls back to a
  // legacy per-value Keystore encryption path that's known to throw
  // (BadPaddingException/KeyStoreException) on some OEMs/devices after a
  // reinstall or Keystore invalidation — a real crash source in release
  // builds that debug testing on one device won't surface.
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _accessTokenKey = 'access_token';
  static const _tokenTypeKey = 'token_type';
  static const _lastEmailKey = 'last_email';

  Future<void> saveAccessToken(String token, {String? tokenType}) async {
    await _storage.write(key: _accessTokenKey, value: token);
    if (tokenType != null) {
      await _storage.write(key: _tokenTypeKey, value: tokenType);
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readTokenType() => _storage.read(key: _tokenTypeKey);

  /// Clears the session (token) but deliberately leaves the cached email
  /// alone — so a re-login (manual or after an expired-session bounce)
  /// still only asks for the password.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _tokenTypeKey);
  }

  Future<void> saveLastEmail(String email) => _storage.write(key: _lastEmailKey, value: email);

  Future<String?> readLastEmail() => _storage.read(key: _lastEmailKey);

  /// Builds the `Authorization` header for authenticated requests.
  /// Throws [ApiException] if there's no stored token.
  Future<Map<String, String>> authHeaders() async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) {
      throw ApiException('You need to sign in again.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
