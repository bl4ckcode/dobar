import 'dart:io';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';
import 'package:dio/dio.dart';

abstract class MenuReaderDatasource {
  Future<MenuExtraction> extractMenuFromImage({
    required File imageFile,
    required int barId,
    String? languageHint,
  });

  Future<MenuExtraction> extractMenuFromUrl({
    required String menuUrl,
    required int barId,
    String? languageHint,
  });
}

class MenuReaderNetworkDatasource implements MenuReaderDatasource {
  final Dio dio;

  MenuReaderNetworkDatasource({required this.dio});

  @override
  Future<MenuExtraction> extractMenuFromImage({
    required File imageFile,
    required int barId,
    String? languageHint,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'menu_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'bar_id': barId,
        if (languageHint != null) 'language_hint': languageHint,
      });

      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.menuExtract}',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      return MenuExtraction.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<MenuExtraction> extractMenuFromUrl({
    required String menuUrl,
    required int barId,
    String? languageHint,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.menuExtract}',
        data: {
          'menu_url': menuUrl,
          'bar_id': barId,
          if (languageHint != null) 'language_hint': languageHint,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      return MenuExtraction.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  Never _handleError(DioException e) {
    final statusCode = e.response?.statusCode;
    final detail = e.response?.data?['detail'];

    if (statusCode == 400) {
      throw ServerException(detail ?? 'Image quality too low for text extraction', statusCode);
    } else if (statusCode == 422) {
      throw ServerException(detail ?? 'No menu items detected', statusCode);
    }

    throw ServerException(detail ?? 'Failed to extract menu', statusCode);
  }
}
