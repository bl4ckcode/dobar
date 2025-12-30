import 'package:barz/core/api/api_endpoints.dart';
import 'package:dio/dio.dart';

class DioNetwork {
  static late Dio appAPI;
  static String? _authToken;

  static void initDio() {
    appAPI = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      validateStatus: (s) => s != null && s < 300,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    appAPI.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static void clearAuthToken() {
    _authToken = null;
  }

  static String? get authToken => _authToken;
}

