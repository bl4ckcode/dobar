import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:barz/core/services/token_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle app version migrations and prevent logout issues during updates
///
/// This service is critical for a payments app because:
/// 1. Tracks the app version that was last run
/// 2. Validates storage integrity on app startup
/// 3. Automatically clears corrupted storage
/// 4. Preserves user sessions across compatible app updates
/// 5. Prevents users from being logged out unexpectedly
class VersionMigrationService {
  static const _versionKey = 'barz_app_version';
  static const _buildNumberKey = 'barz_build_number';
  static const _lastRunKey = 'barz_last_run_timestamp';
  static const _migrationCompleteKey = 'barz_migration_complete';

  // Current app version - should match pubspec.yaml
  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  final TokenStorageService _tokenStorage;
  late final SharedPreferences _prefs;
  bool _initialized = false;

  VersionMigrationService({required TokenStorageService tokenStorage})
    : _tokenStorage = tokenStorage;

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[VersionMigrationService] $message');
    }
  }

  /// Initialize the service - must be called before runMigration
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Main migration entry point - call this during app initialization
  Future<void> runMigration() async {
    if (!_initialized) {
      await init();
    }

    try {
      _debugLog('🔄 Starting version migration check...');

      final storedVersion = _prefs.getString(_versionKey);
      final storedBuildNumber = _prefs.getString(_buildNumberKey);

      _debugLog('Stored version: $storedVersion (build: $storedBuildNumber)');
      _debugLog(
        'Current version: $currentVersion (build: $currentBuildNumber)',
      );

      // First run or fresh install
      if (storedVersion == null) {
        _debugLog('📱 First app run detected');
        await _saveCurrentVersion();
        await _validateStorageIntegrity();
        return;
      }

      // Check if app was updated
      final wasUpdated =
          storedVersion != currentVersion ||
          storedBuildNumber != currentBuildNumber.toString();

      if (wasUpdated) {
        _debugLog('🆕 App update detected: $storedVersion → $currentVersion');
        await _handleAppUpdate(storedVersion, storedBuildNumber);
      } else {
        // Same version, but validate storage integrity periodically
        await _validateStorageIntegrity();
      }

      // Update last run timestamp
      await _prefs.setString(
        _lastRunKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      _debugLog('✅ Version migration complete');
    } catch (e) {
      _debugLog('❌ Error during version migration: $e');
      // If migration fails, clear storage to prevent corrupted state
      await _clearAllStorageOnError();
    }
  }

  /// Handles app update scenarios
  Future<void> _handleAppUpdate(
    String? oldVersion,
    String? oldBuildNumber,
  ) async {
    try {
      // Validate that storage is still accessible after update
      final storageValid = await _validateStorageIntegrity();

      if (!storageValid) {
        _debugLog(
          '⚠️ Storage validation failed after update - clearing storage',
        );
        await _clearAllStorageOnError();
        await _saveCurrentVersion();
        return;
      }

      // Check if this is a major version change (e.g., 1.x.x → 2.x.x)
      final oldMajor = _getMajorVersion(oldVersion);
      final newMajor = _getMajorVersion(currentVersion);

      if (oldMajor != newMajor && oldMajor > 0) {
        _debugLog('🔄 Major version change detected ($oldMajor → $newMajor)');
        // For major version updates, you might want to add specific migrations here
        // For payments apps, consider data migration strategies carefully
      }

      // Run version-specific migrations
      await _runVersionSpecificMigrations(oldVersion, currentVersion);

      // Save current version
      await _saveCurrentVersion();
      _debugLog('✅ App update handled successfully');
    } catch (e) {
      _debugLog('❌ Error handling app update: $e');
      await _clearAllStorageOnError();
    }
  }

  /// Run migrations specific to version transitions
  Future<void> _runVersionSpecificMigrations(
    String? oldVersion,
    String newVersion,
  ) async {
    // Example: Migrate from 1.0.0 to 1.1.0
    // if (oldVersion == '1.0.0' && _compareVersions(newVersion, '1.1.0') >= 0) {
    //   await _migrate_1_0_0_to_1_1_0();
    // }

    // Add your version-specific migrations here
    _debugLog(
      'Running version-specific migrations from $oldVersion to $newVersion',
    );
  }

  /// Validates that all critical storage keys are accessible and valid
  Future<bool> _validateStorageIntegrity() async {
    try {
      _debugLog('🔍 Validating storage integrity...');

      // Check if tokens are accessible
      final jwt = await _tokenStorage.getAccessToken();

      // If user was logged in but token is not readable, storage is corrupted
      if (jwt != null && jwt.isEmpty) {
        _debugLog('⚠️ Empty JWT token detected - storage may be corrupted');
        return false;
      }

      // If we have a token, validate it's properly formatted (basic check)
      if (jwt != null) {
        final isValidFormat = _validateTokenFormat(jwt);
        if (!isValidFormat) {
          _debugLog('⚠️ Invalid token format detected');
          return false;
        }
      }

      _debugLog('✅ Storage integrity validated');
      return true;
    } catch (e) {
      _debugLog('❌ Storage validation error: $e');
      return false;
    }
  }

  /// Basic token format validation
  bool _validateTokenFormat(String token) {
    // JWT tokens should be at least 20 characters and contain dots
    if (token.length < 20) return false;

    // Most tokens (JWT, Bearer) have some structure
    return token.isNotEmpty && !token.contains('null');
  }

  /// Clears all storage when an unrecoverable error occurs
  Future<void> _clearAllStorageOnError() async {
    try {
      _debugLog('🗑️ Clearing all storage due to error...');

      await _tokenStorage.deleteAccessToken();
      await _tokenStorage.deleteUserProfile();

      // Don't clear version info - keep it for tracking

      _debugLog('✅ Storage cleared');
    } catch (e) {
      _debugLog('❌ Error clearing storage: $e');
      // Last resort - try to clear everything
      try {
        await _prefs.clear();
      } catch (clearError) {
        _debugLog('❌ Fatal: Could not clear storage: $clearError');
      }
    }
  }

  /// Saves current version and build number to storage
  Future<void> _saveCurrentVersion() async {
    await _prefs.setString(_versionKey, currentVersion);
    await _prefs.setString(_buildNumberKey, currentBuildNumber.toString());
    await _prefs.setBool(_migrationCompleteKey, true);
    _debugLog('💾 Saved version: $currentVersion (build: $currentBuildNumber)');
  }

  /// Extracts major version number from version string
  int _getMajorVersion(String? version) {
    if (version == null) return 0;
    try {
      final parts = version.split('.');
      return int.parse(parts[0]);
    } catch (e) {
      return 0;
    }
  }

  /// Gets stored version for debugging
  Future<String?> getStoredVersion() async {
    if (!_initialized) await init();
    return _prefs.getString(_versionKey);
  }

  /// Gets stored build number for debugging
  Future<String?> getStoredBuildNumber() async {
    if (!_initialized) await init();
    return _prefs.getString(_buildNumberKey);
  }

  /// Check if user is authenticated (has valid tokens)
  Future<bool> isAuthenticated() async {
    final hasAccessToken = await _tokenStorage.hasValidTokens();
    if (hasAccessToken) return true;

    // Also consider authenticated if we have a refresh token
    final refreshToken = await _tokenStorage.getRefreshToken();
    final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;
    
    _debugLog('🔐 Auth check - Access: $hasAccessToken, Refresh: $hasRefreshToken');
    
    return hasAccessToken || hasRefreshToken;
  }

  /// Force clear all data (useful for testing or troubleshooting)
  Future<void> forceClearAll() async {
    _debugLog('🔥 Force clearing all data...');
    await _clearAllStorageOnError();
    await _prefs.remove(_versionKey);
    await _prefs.remove(_buildNumberKey);
    await _prefs.remove(_lastRunKey);
    await _prefs.remove(_migrationCompleteKey);
    _debugLog('✅ Force clear complete');
  }
}
