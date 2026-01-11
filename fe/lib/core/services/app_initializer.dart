import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:barz/core/services/version_migration_service.dart';

/// AppInitializer handles all startup tasks for the app
/// 
/// This is critical for a payments app to ensure:
/// 1. Version migrations are run before the app starts
/// 2. Storage integrity is validated
/// 3. User sessions are preserved across updates
/// 4. Proper error handling during initialization
class AppInitializer {
  final VersionMigrationService _versionMigrationService;

  AppInitializer({
    required VersionMigrationService versionMigrationService,
  }) : _versionMigrationService = versionMigrationService;

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AppInitializer] $message');
    }
  }

  /// Run all initialization tasks
  /// This should be called after dependencies are registered but before runApp
  Future<void> run() async {
    _debugLog('🚀 Starting app initialization...');
    
    try {
      // 1. Run version migrations first
      await _runVersionMigrations();
      
      // 2. Initialize any other startup services
      await _initializeServices();
      
      // 3. Preload any necessary data
      await _preloadData();
      
      _debugLog('✅ App initialization complete');
    } catch (e, stackTrace) {
      _debugLog('❌ App initialization failed: $e');
      _debugLog('Stack trace: $stackTrace');
      // Don't rethrow - let the app start anyway and handle errors gracefully
    }
  }

  Future<void> _runVersionMigrations() async {
    _debugLog('Running version migrations...');
    await _versionMigrationService.init();
    await _versionMigrationService.runMigration();
  }

  Future<void> _initializeServices() async {
    _debugLog('Initializing services...');
    // Check auth status at startup
    final isAuth = await isUserAuthenticated();
    _debugLog('🔐 Authenticated at startup: $isAuth');
  }

  Future<void> _preloadData() async {
    _debugLog('Preloading data...');
    // Add any data preloading here
    // e.g., user preferences, cached data, etc.
  }

  /// Check if user is authenticated
  Future<bool> isUserAuthenticated() async {
    return await _versionMigrationService.isAuthenticated();
  }

  /// Get the stored app version
  Future<String?> getStoredVersion() async {
    return await _versionMigrationService.getStoredVersion();
  }
}
