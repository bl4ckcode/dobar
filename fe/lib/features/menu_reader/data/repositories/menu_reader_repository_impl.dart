import 'dart:io';
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
    required File imageFile,
    required int barId,
    String? languageHint,
  }) async {
    try {
      final result = await datasource.extractMenuFromImage(
        imageFile: imageFile,
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
    required int menuId,
    required List<ExtractedCategory> categories,
  }) async {
    try {
      int successCount = 0;
      int totalItems = 0;

      for (final category in categories) {
        for (final item in category.items) {
          if (!item.isSelected) continue;
          totalItems++;
          
          await dio.post(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.menuItems(menuId)}/',
            data: {
              'name': item.name,
              'description': item.description,
              'price': item.price,
              'category': category.name,
              'is_available': true,
            },
          );
          successCount++;
        }
      }

      if (successCount == 0 && totalItems > 0) {
        return const Left(ServerFailure('Failed to save any menu items', null));
      }

      return const Right(true);
    } on DioException catch (e) {
      return Left(ServerFailure(
        e.response?.data?['detail'] ?? 'Failed to save menu items',
        e.response?.statusCode,
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to save menu items: $e', null));
    }
  }
}
