// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/auth_response.dart';
import 'package:barz/core/services/token_storage_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final TokenStorageService? tokenStorage;
  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;
  final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  AuthInterceptor({this.tokenStorage});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    _accessToken ??= await tokenStorage?.getAccessToken();
    _refreshToken ??= await tokenStorage?.getRefreshToken();
    
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    options.headers['Accept'] = 'application/json';
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isAuthEndpoint(err.requestOptions.path)) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        try {
          err.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
          final response = await _refreshDio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          if (kDebugMode) print('[AUTH] Retry after refresh failed: $e');
        }
      }
      await _clearTokens();
    }

    final message = _extractErrorMessage(err);
    if (kDebugMode) {
      print('[DIO] *** Error Response ***');
      print('[DIO] uri: ${err.requestOptions.uri}');
      print('[DIO] status: ${err.response?.statusCode}');
      print('[DIO] message: ${message ?? err.message}');
    }
    
    if (message != null) {
      return handler.reject(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: message,
        message: message,
      ));
    }
    super.onError(err, handler);
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/');
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing || _refreshToken == null) return false;
    _isRefreshing = true;
    
    try {
      if (kDebugMode) print('[AUTH] Attempting token refresh...');
      
      final response = await _refreshDio.post(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': _refreshToken},
      );
      
      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveTokens(authResponse.accessToken, authResponse.refreshToken);
        if (kDebugMode) print('[AUTH] Token refreshed successfully');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[AUTH] Token refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
    return false;
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await tokenStorage?.saveAccessToken(accessToken);
    if (refreshToken.isNotEmpty) {
      await tokenStorage?.saveRefreshToken(refreshToken);
    }
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await tokenStorage?.clearAll();
    if (kDebugMode) print('[AUTH] Tokens cleared');
  }

  String? _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data == null) return error.message;

    if (data is String) {
      try {
        return _extractFromJson(jsonDecode(data));
      } catch (_) {
        return data.isNotEmpty ? data : null;
      }
    }
    if (data is Map<String, dynamic>) return _extractFromJson(data);
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is String) return first;
      if (first is Map<String, dynamic>) return _extractFromJson(first);
    }
    return error.message;
  }

  String? _extractFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return json['message'] as String? ??
        json['detail'] as String? ??
        json['error'] as String? ??
        (json['details'] as Map?)?.values.expand((v) => v is List ? v : [v]).join(', ');
  }

  void setTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    tokenStorage?.saveAccessToken(accessToken);
    if (refreshToken.isNotEmpty) {
      tokenStorage?.saveRefreshToken(refreshToken);
    }
    if (kDebugMode) print('[AUTH] Tokens set');
  }

  Future<void> clearTokens() => _clearTokens();
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> loadTokens() async {
    _accessToken = await tokenStorage?.getAccessToken();
    _refreshToken = await tokenStorage?.getRefreshToken();
    if (kDebugMode && _accessToken != null) print('[AUTH] Tokens loaded from storage');
  }

  Future<bool> isAuthenticated() async {
    if (_accessToken != null) return true;
    final stored = await tokenStorage?.getAccessToken();
    return stored != null && stored.isNotEmpty;
  }
}
