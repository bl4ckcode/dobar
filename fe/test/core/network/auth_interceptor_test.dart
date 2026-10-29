import 'dart:typed_data';

import 'package:barz/core/network/auth_interceptor.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTokenStorageService extends Mock implements TokenStorageService {}

class _RecordingAdapter implements HttpClientAdapter {
  String? authorizationHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizationHeader = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MockTokenStorageService tokenStorage;
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    tokenStorage = _MockTokenStorageService();
    when(
      () => tokenStorage.getAccessToken(),
    ).thenAnswer((_) async => 'app-access-token');
    when(
      () => tokenStorage.getRefreshToken(),
    ).thenAnswer((_) async => 'refresh-token');

    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(AuthInterceptor(tokenStorage: tokenStorage));
    dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    dio.close(force: true);
  });

  test('adds the stored app bearer token to protected requests', () async {
    await dio.get('/profile');

    expect(adapter.authorizationHeader, 'Bearer app-access-token');
  });

  test('preserves the Firebase bearer token on phone login', () async {
    await dio.post(
      '/auth/phone-login',
      options: Options(
        headers: {'Authorization': 'Bearer firebase-id-token'},
      ),
    );

    expect(adapter.authorizationHeader, 'Bearer firebase-id-token');
  });
}
