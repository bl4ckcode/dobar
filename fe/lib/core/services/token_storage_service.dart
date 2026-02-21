import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing authentication tokens and user info
/// This replaces the simpler SecureStorage for comprehensive token management
class TokenStorageService {
  FlutterSecureStorage? _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  TokenStorageService() {
    // Configure storage with platform-specific options
    if (!kIsWeb) {
      // Mobile: Use default secure storage with accessibility options
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage!.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage!.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage!.delete(key: key);
    }
  }

  Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userNameKey);
    } else {
      await _storage!.deleteAll();
    }
  }

  // Access Token
  Future<void> saveAccessToken(String token) async {
    try {
      await _write(_accessTokenKey, token);
      _log('[TOKEN] Access token saved (${token.length} chars)');
    } catch (e) {
      _log('[TOKEN] ERROR saving access token: $e');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _read(_accessTokenKey);
      _log(
        '[TOKEN] Access token read: ${token != null ? "exists (${token.length} chars)" : "null"}',
      );
      return token;
    } catch (e) {
      _log('[TOKEN] ERROR reading access token: $e');
      return null;
    }
  }

  Future<void> deleteAccessToken() async {
    await _delete(_accessTokenKey);
    _log('[TOKEN] Access token deleted');
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
    _log('[TOKEN] Refresh token saved');
  }

  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _delete(_refreshTokenKey);
    _log('[TOKEN] Refresh token deleted');
  }

  // User Info
  Future<void> saveUserInfo({
    required String userId,
    String? email,
    String? name,
  }) async {
    await _write(_userIdKey, userId);
    if (email != null) await _write(_userEmailKey, email);
    if (name != null) await _write(_userNameKey, name);
    _log('[TOKEN] User info saved: $userId');
  }

  Future<Map<String, String?>> getUserInfo() async {
    return {
      'userId': await _read(_userIdKey),
      'email': await _read(_userEmailKey),
      'name': await _read(_userNameKey),
    };
  }

  // Token Validation
  Future<bool> hasValidTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Clear All
  Future<void> clearAll() async {
    await _deleteAll();
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
    _log(
      '[TOKEN DEBUG] Refresh Token: ${refreshToken != null ? "present" : "null"}',
    );
    _log('[TOKEN DEBUG] User Info: $userInfo');
  }
}
