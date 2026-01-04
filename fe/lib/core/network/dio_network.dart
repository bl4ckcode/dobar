import 'dart:convert';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class DioNetwork {
  static late Dio appAPI;
  static String? _authToken;
  static TokenStorageService? _tokenStorage;

  static void initDio({TokenStorageService? tokenStorage}) {
    _tokenStorage = tokenStorage;
    
    appAPI = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      validateStatus: (s) => s != null && s < 300,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Auth interceptor with async token loading
    appAPI.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Try to get token from memory first, then from storage
        String? token = _authToken;
        if (token == null && _tokenStorage != null) {
          token = await _tokenStorage!.getAccessToken();
          if (token != null) {
            _authToken = token; // Cache it in memory
          }
        }
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - clear token and let caller handle
        if (error.response?.statusCode == 401) {
          await clearAuthToken();
        }
        
        // Extract error message from response
        final errorMessage = _extractErrorMessage(error);
        if (errorMessage != null) {
          final newError = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: errorMessage,
            message: errorMessage,
          );
          return handler.reject(newError);
        }
        return handler.next(error);
      },
    ));

    // Logging interceptor - only in debug mode
    if (kDebugMode) {
      appAPI.interceptors.add(
        LogInterceptor(
          responseBody: true,
          requestBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
          // ignore: avoid_print
          logPrint: (obj) => print('[DIO] $obj'),
        ),
      );
    }
  }

  /// Extract error message from various response formats
  static String? _extractErrorMessage(DioException error) {
    final response = error.response;
    if (response == null) return error.message;

    final data = response.data;

    // Handle String response
    if (data is String) {
      try {
        final jsonData = json.decode(data);
        return _extractFromJson(jsonData);
      } catch (_) {
        return data.isNotEmpty ? data : null;
      }
    }

    // Handle Map response
    if (data is Map<String, dynamic>) {
      return _extractFromJson(data);
    }

    // Handle List response
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is String) return first;
      if (first is Map<String, dynamic>) return _extractFromJson(first);
    }

    return error.message;
  }

  /// Extract error message from JSON data
  static String? _extractFromJson(dynamic jsonData) {
    if (jsonData is Map<String, dynamic>) {
      // Common error response formats from backends
      return jsonData['detail'] as String? ??
          jsonData['message'] as String? ??
          jsonData['error'] as String? ??
          jsonData['errors']?.toString();
    }
    return null;
  }

  static void setAuthToken(String token) {
    _authToken = token;
    // Also persist to storage
    _tokenStorage?.saveAccessToken(token);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AUTH] Token set: ${token.substring(0, 20.clamp(0, token.length))}...');
    }
  }

  static Future<void> clearAuthToken() async {
    _authToken = null;
    await _tokenStorage?.clearAll();
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AUTH] Token cleared');
    }
  }

  static String? get authToken => _authToken;
  
  /// Load token from storage into memory (call on app start)
  static Future<void> loadTokenFromStorage() async {
    if (_tokenStorage != null) {
      _authToken = await _tokenStorage!.getAccessToken();
      if (kDebugMode && _authToken != null) {
        // ignore: avoid_print
        print('[AUTH] Token loaded from storage');
      }
    }
  }
  
  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    if (_authToken != null) return true;
    if (_tokenStorage != null) {
      final token = await _tokenStorage!.getAccessToken();
      return token != null && token.isNotEmpty;
    }
    return false;
  }
}

