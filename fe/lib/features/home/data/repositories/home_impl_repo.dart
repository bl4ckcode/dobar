import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/home/data/data_sources/home_impl_api.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';
import 'package:barz/features/home/domain/repositories/abstract_home_repository.dart';
import 'package:dartz/dartz.dart';

class HomeRepositoryImpl extends AbstractHomeRepository {
  final HomeImplApi homeApi;

  HomeRepositoryImpl(this.homeApi);

  @override
  Future<Either<Failure, HomeModel?>> getHome(HomeParams params) async {
    try {
      final result = await homeApi.getHome(params);
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
