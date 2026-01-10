import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Consolidated secure storage service for all app secrets
/// Used by VersionMigrationService for token validation and by auth for token management
class SecureStorage {
  // Legacy keys (for migration compatibility)
  static const _jwtKey = 'jwt_token';
  static const _userKey = 'user_profile';
  
  // New keys (aligned with TokenStorageService)
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  
  late final FlutterSecureStorage _storage;

  SecureStorage() {
    // Configure storage with platform-specific options
    if (kIsWeb) {
      _storage = const FlutterSecureStorage(
        webOptions: WebOptions(
          dbName: 'barz_secure_storage',
          publicKey: 'barz_public_key',
        ),
      );
    } else {
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
      print('[SecureStorage] $message');
    }
  }

  // ============ JWT / Access Token ============
  
  /// Save JWT/access token - uses new key but checks legacy for migration
  Future<void> saveJwt(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
    // Also write to legacy key for compatibility
    await _storage.write(key: _jwtKey, value: token);
    _log('Token saved');
  }

  /// Get JWT/access token - checks new key first, then legacy for migration
  Future<String?> getJwt() async {
    var token = await _storage.read(key: _accessTokenKey);
    if (token == null) {
      // Check legacy key
      token = await _storage.read(key: _jwtKey);
      if (token != null) {
        // Migrate to new key
        await _storage.write(key: _accessTokenKey, value: token);
        _log('Migrated token from legacy key');
      }
    }
    return token;
  }

  Future<void> deleteJwt() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _jwtKey);
    _log('Token deleted');
  }

  // ============ Refresh Token ============
  
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
    _log('Refresh token saved');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
    _log('Refresh token deleted');
  }

  // ============ User Profile ============
  
  Future<void> saveUserProfile(String userJson) async {
    await _storage.write(key: _userKey, value: userJson);
    _log('User profile saved');
  }

  Future<String?> getUserProfile() async {
    return await _storage.read(key: _userKey);
  }

  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _userKey);
    _log('User profile deleted');
  }

  // ============ User Info (Individual Fields) ============
  
  Future<void> saveUserInfo({
    required String userId,
    String? email,
    String? name,
  }) async {
    await _storage.write(key: _userIdKey, value: userId);
    if (email != null) await _storage.write(key: _userEmailKey, value: email);
    if (name != null) await _storage.write(key: _userNameKey, value: name);
    _log('User info saved: $userId');
  }

  Future<Map<String, String?>> getUserInfo() async {
    return {
      'userId': await _storage.read(key: _userIdKey),
      'email': await _storage.read(key: _userEmailKey),
      'name': await _storage.read(key: _userNameKey),
    };
  }

  // ============ Utilities ============
  
  /// Check if user has valid authentication
  Future<bool> hasValidTokens() async {
    final token = await getJwt();
    return token != null && token.isNotEmpty && token.length > 10;
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _log('All secure storage cleared');
  }

  /// Debug print all tokens (only in debug mode)
  Future<void> debugPrint() async {
    if (!kDebugMode) return;
    
    final accessToken = await getJwt();
    final refreshToken = await getRefreshToken();
    final userInfo = await getUserInfo();
    
    final tokenPreview = accessToken != null && accessToken.length > 20 
        ? '${accessToken.substring(0, 20)}...' 
        : accessToken ?? 'null';
    
    _log('Access Token: $tokenPreview');
    _log('Refresh Token: ${refreshToken != null ? "present" : "null"}');
    _log('User Info: $userInfo');
  }
}
