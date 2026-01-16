import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/menu_reader/data/datasources/menu_reader_datasource.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';
import 'package:barz/features/menu_reader/domain/repositories/menu_reader_repository.dart';

class MenuReaderRepositoryImpl implements MenuReaderRepository {
  final MenuReaderDatasource datasource;
  final Dio dio;

  MenuReaderRepositoryImpl({
    required this.datasource,
    required this.dio,
  });

  @override
  Future<Either<Failure, MenuExtraction>> extractMenuFromImage({
    required Uint8List imageBytes,
    required String fileName,
    required int barId,
    String? languageHint,
  }) async {
    try {
      final result = await datasource.extractMenuFromImage(
        imageBytes: imageBytes,
        fileName: fileName,
        barId: barId,
        languageHint: languageHint,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure('Failed to extract menu: $e', null));
    }
  }

  @override
  Future<Either<Failure, MenuExtraction>> extractMenuFromUrl({
    required String menuUrl,
    required int barId,
    String? languageHint,
  }) async {
    try {
      final result = await datasource.extractMenuFromUrl(
        menuUrl: menuUrl,
        barId: barId,
        languageHint: languageHint,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure('Failed to extract menu from URL: $e', null));
    }
  }

  @override
  Future<Either<Failure, bool>> saveExtractedItems({
    required int barId,
    required List<ExtractedCategory> categories,
  }) async {
    try {
      final menuId = await _getOrCreateMenuForBar(barId);
      if (menuId == null) {
        return const Left(ServerFailure('Failed to get or create menu', null));
      }

      final items = <Map<String, dynamic>>[];
      for (final category in categories) {
        for (final item in category.items) {
          if (!item.isSelected) continue;
          items.add({
            'name': item.name,
            'description': item.description,
            'price': item.price,
            'category': category.name,
            'available': true,
          });
        }
      }

      if (items.isEmpty) {
        return const Left(ServerFailure('No items selected', null));
      }

      await dio.post(
        '${ApiEndpoints.baseUrl}/menus/$menuId/items/bulk',
        data: {'items': items},
      );

      return const Right(true);
    } on DioException catch (e) {
      return Left(ServerFailure(
        e.response?.data?['message'] ?? 'Failed to save menu items',
        e.response?.statusCode,
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to save menu items: $e', null));
    }
  }

  Future<int?> _getOrCreateMenuForBar(int barId) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.menusForBar(barId)}',
      );
      
      final menus = response.data as List<dynamic>;
      if (menus.isNotEmpty) {
        return menus.first['id'] as int;
      }
      
      final createResponse = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.menusCreate}',
        data: {
          'bar_id': barId,
          'name': 'Menu Principal',
          'description': 'Menu criado automaticamente',
          'is_active': true,
        },
      );
      
      return createResponse.data['id'] as int;
    } catch (e) {
      return null;
    }
  }
}
