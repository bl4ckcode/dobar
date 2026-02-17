import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/error/error_codes.dart';
import 'package:barz/core/error/failures.dart';
import '../../domain/models/home_model.dart';
import '../datasources/home_datasource.dart';

import '../repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeDatasource datasource;

  HomeRepositoryImpl({required this.datasource});

  @override
  Future<Either<Failure, HomeModel>> getHomeData({
    double? lat,
    double? lng,
  }) async {
    try {
      final result = await datasource.getHomeData(lat: lat, lng: lng);
      return Right(result);
    } on DioException catch (e) {
      return Left(
        ServerFailure.fromCode(ErrorCode.serverUnavailable, e.message),
      );
    } catch (e) {
      return Left(ServerFailure.unknown(e.toString()));
    }
  }
}
