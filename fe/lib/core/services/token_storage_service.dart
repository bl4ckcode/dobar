import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing authentication tokens and user info
/// This replaces the simpler SecureStorage for comprehensive token management
class TokenStorageService {
  late final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  TokenStorageService() {
    // Configure storage with platform-specific options
    if (kIsWeb) {
      // Web: Use localStorage with proper options
      _storage = const FlutterSecureStorage(
        webOptions: WebOptions(
          dbName: 'barz_secure_storage',
          publicKey: 'barz_public_key',
        ),
      );
    } else {
      // Mobile: Use default secure storage with accessibility options
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  // Access Token
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      _log('[TOKEN] Access token saved (${token.length} chars)');
    } catch (e) {
      _log('[TOKEN] ERROR saving access token: $e');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _accessTokenKey);
      _log('[TOKEN] Access token read: ${token != null ? "exists (${token.length} chars)" : "null"}');
      return token;
    } catch (e) {
      _log('[TOKEN] ERROR reading access token: $e');
      return null;
    }
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
    _log('[TOKEN] Access token deleted');
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
    _log('[TOKEN] Refresh token saved');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
    _log('[TOKEN] Refresh token deleted');
  }

  // User Info
  Future<void> saveUserInfo({
    required String userId,
    String? email,
    String? name,
  }) async {
    await _storage.write(key: _userIdKey, value: userId);
    if (email != null) await _storage.write(key: _userEmailKey, value: email);
    if (name != null) await _storage.write(key: _userNameKey, value: name);
    _log('[TOKEN] User info saved: $userId');
  }

  Future<Map<String, String?>> getUserInfo() async {
    return {
      'userId': await _storage.read(key: _userIdKey),
      'email': await _storage.read(key: _userEmailKey),
      'name': await _storage.read(key: _userNameKey),
    };
  }

  // Token Validation
  Future<bool> hasValidTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Clear All
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _log('[TOKEN] All tokens and user info cleared');
  }

  // Debug
  Future<void> debugPrintTokens() async {
    if (!kDebugMode) return;
    
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final userInfo = await getUserInfo();
    
    final tokenPreview = accessToken != null && accessToken.length > 20 
        ? '${accessToken.substring(0, 20)}...' 
        : accessToken ?? 'null';
    
    _log('[TOKEN DEBUG] Access Token: $tokenPreview');
    _log('[TOKEN DEBUG] Refresh Token: ${refreshToken != null ? "present" : "null"}');
    _log('[TOKEN DEBUG] User Info: $userInfo');
  }
}
