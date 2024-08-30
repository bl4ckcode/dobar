import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/data/data_sources/abstract_login_api.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:dartz/dartz.dart';

class LoginRepositoryImpl extends AbstractLoginRepository {
  final AbstractLoginApi loginApi;

  LoginRepositoryImpl(
    this.loginApi,
  );

  @override
  Future<Either<Failure, String?>> login(LoginParams params) async {
    try {
      final result = await loginApi.login(params);
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
