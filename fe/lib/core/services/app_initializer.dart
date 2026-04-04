import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/services/version_migration_service.dart';
import 'package:barz/core/services/notifications/notification_navigation_handler.dart';

class AppInitializer {
  final VersionMigrationService _versionMigrationService;
  final NotificationNavigationHandler _notificationNavigationHandler;
  final Dio _dio;

  AppInitializer({
    required VersionMigrationService versionMigrationService,
    required NotificationNavigationHandler notificationNavigationHandler,
    required Dio dio,
  }) : _versionMigrationService = versionMigrationService,
       _notificationNavigationHandler = notificationNavigationHandler,
       _dio = dio;

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AppInitializer] $message');
    }
  }

  Future<void> run() async {
    _debugLog('🚀 Starting app initialization...');

    try {
      await _runVersionMigrations();
      await _initializeServices();
      await _preloadData();
      _debugLog('✅ App initialization complete');
    } catch (e, stackTrace) {
      _debugLog('❌ App initialization failed: $e');
      _debugLog('Stack trace: $stackTrace');
    }
  }

  Future<void> _runVersionMigrations() async {
    _debugLog('Running version migrations...');
    await _versionMigrationService.init();
    await _versionMigrationService.runMigration();
  }

  Future<void> _initializeServices() async {
    _debugLog('Initializing services...');

    _notificationNavigationHandler.init();

    final isAuth = await isUserAuthenticated();
    _debugLog('🔐 Authenticated at startup: $isAuth');

    if (isAuth) {
      await _registerFcmToken();
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          _debugLog('⏳ Waiting for APNS token on iOS...');
          // On iOS, FCM registration needs APNS token. If null, we'll wait 
          // and retry or rely on onTokenRefresh if the system handles it.
          // We'll attempt a short delay and retry once.
          await Future.delayed(const Duration(seconds: 3));
          final retryToken = await FirebaseMessaging.instance.getAPNSToken();
          if (retryToken == null) {
            _debugLog('⚠️ APNS token still null after retry.');
            // We don't return here because getToken() might still work if 
            // swizzling is enabled, but it's safer to wait.
          }
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      await _dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.fcmToken}',
        data: {'token': token, 'platform': platform},
      );
      _debugLog('📱 FCM token registered ($platform)');

      FirebaseMessaging.instance.onTokenRefresh.listen((refreshedToken) async {
        try {
          await _dio.put(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.fcmToken}',
            data: {'token': refreshedToken, 'platform': platform},
          );
          _debugLog('📱 FCM token refreshed');
        } catch (e) {
          _debugLog('⚠️ FCM token refresh failed: $e');
        }
      });
    } catch (e) {
      _debugLog('⚠️ FCM token registration failed: $e');
    }
  }

  Future<void> _preloadData() async {
    _debugLog('Preloading data...');
  }

  Future<bool> isUserAuthenticated() async {
    return await _versionMigrationService.isAuthenticated();
  }

  Future<String?> getStoredVersion() async {
    return await _versionMigrationService.getStoredVersion();
  }
}
