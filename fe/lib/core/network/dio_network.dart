// ignore_for_file: avoid_print
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/auth_interceptor.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class DioNetwork {
  static late Dio appAPI;
  static AuthInterceptor? _authInterceptor;

  static void initDio({
    TokenStorageService? tokenStorage,
    OnAuthExpiredCallback? onAuthExpired,
  }) {
    _authInterceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      onAuthExpired: onAuthExpired,
    );

    appAPI = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        validateStatus: (s) => s != null && s < 300,
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    appAPI.interceptors.add(_authInterceptor!);

    if (kDebugMode) {
      appAPI.interceptors.add(
        LogInterceptor(
          responseBody: true,
          requestBody: true,
          requestHeader: true,
          responseHeader: false,
          error: false,
          logPrint: (obj) => print('[DIO] $obj'),
        ),
      );
    }
  }

  static void setTokens(String accessToken, String refreshToken) =>
      _authInterceptor?.setTokens(accessToken, refreshToken);
  static Future<void> clearTokens() =>
      _authInterceptor?.clearTokens() ?? Future.value();
  static String? get accessToken => _authInterceptor?.accessToken;
  static String? get refreshToken => _authInterceptor?.refreshToken;
  static Future<void> loadTokensFromStorage() =>
      _authInterceptor?.loadTokens() ?? Future.value();
  static Future<bool> isAuthenticated() =>
      _authInterceptor?.isAuthenticated() ?? Future.value(false);
}
