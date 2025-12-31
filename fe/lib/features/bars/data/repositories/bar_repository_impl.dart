import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:dartz/dartz.dart';

class BarRepositoryImpl extends AbstractBarRepository {
  final BarNetworkDataSource networkDataSource;

  BarRepositoryImpl({required this.networkDataSource});

  @override
  Future<Either<Failure, List<BarModel>>> getNearbyBars(
      double lat, double lng, double maxDistance) async {
    try {
      final result =
          await networkDataSource.getNearbyBars(lat, lng, maxDistance);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, BarModel>> getBar(int barId) async {
    try {
      final result = await networkDataSource.getBar(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<MenuModel>>> getBarMenus(int barId) async {
    try {
      final result = await networkDataSource.getBarMenus(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
