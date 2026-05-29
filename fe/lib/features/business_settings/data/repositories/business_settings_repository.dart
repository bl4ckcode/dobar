import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/business_settings/domain/models/bar_details.dart';
import 'package:barz/features/business_settings/domain/models/contact_settings.dart';
import 'package:barz/features/business_settings/domain/models/delete_result.dart';
import 'package:barz/features/business_settings/domain/models/deactivate_result.dart';
import 'package:barz/features/business_settings/domain/models/reactivate_result.dart';
import 'package:barz/features/business_settings/domain/repositories/abstract_business_settings_repository.dart';

class BusinessSettingsRepository implements BusinessSettingsRepositoryInterface {
  final Dio _dio;

  BusinessSettingsRepository() : _dio = DioNetwork.appAPI;

  @override
  Future<Either<Failure, BarDetails>> getBarDetails(int barId) async {
    try {
      final res = await _dio.get(ApiEndpoints.barDetails(barId));
      return Right(BarDetails.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, BarDetails>> updateBarDetails(
    int barId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.put(ApiEndpoints.barDetails(barId), data: data);
      return Right(BarDetails.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, ContactSettings>> getContactSettings(int barId) async {
    try {
      final res = await _dio.get(ApiEndpoints.barContact(barId));
      return Right(ContactSettings.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, ContactSettings>> updateContactSettings(
    int barId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.put(ApiEndpoints.barContact(barId), data: data);
      return Right(ContactSettings.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, DeleteResult>> deleteBusinessData(int barId) async {
    try {
      final res = await _dio.delete(ApiEndpoints.barDeleteData(barId));
      return Right(DeleteResult.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, DeactivateResult>> deactivateAccount(
    int barId, {
    String? reason,
    String? estimatedReturnDate,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.barDeactivate(barId),
        data: {
          if (reason != null) 'reason': reason,
          if (estimatedReturnDate != null) 'estimated_return_date': estimatedReturnDate,
        },
      );
      return Right(DeactivateResult.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, ReactivateResult>> reactivateAccount(int barId) async {
    try {
      final res = await _dio.post(ApiEndpoints.barReactivate(barId));
      return Right(ReactivateResult.fromJson(res.data));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure('Connection timeout');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 400 && statusCode < 500) {
            return ServerFailure('Client error: $statusCode', statusCode);
          } else if (statusCode >= 500) {
            return ServerFailure('Server error: $statusCode', statusCode);
          }
        }
        return ServerFailure('Unexpected error: $statusCode', statusCode);
      case DioExceptionType.cancel:
        return ServerFailure('Request cancelled', null);
      case DioExceptionType.connectionError:
        return NetworkFailure('No internet connection');
      default:
        return ServerFailure('Unexpected error: ${error.message}', null);
    }
  }
}