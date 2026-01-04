import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/data/data_sources/local/login_local_datasource.dart';
import 'package:barz/features/authentication/data/data_sources/login_network_datasource.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginRepositoryImpl extends AbstractLoginRepository {
  final LoginNetworkDataSource networkDataSource;
  final LoginLocalDataSource localDataSource;

  LoginRepositoryImpl({
    required this.networkDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, String?>> completeLoginWithBackend(User? user) async {
    try {
      // Call the network data source for phone authentication
      final result = await networkDataSource.completeLoginWithBackend(user);

      // Cache the token locally
      if (result.result != null) {
        await localDataSource.cacheUserToken(result.result!);
      }

      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, String?>> loginWithGoogle(LoginParams params) async {
    try {
      // Call the network data source for Google Sign-In
      final result = await networkDataSource.loginWithGoogle(params);

      // Cache the token locally
      if (result.result != null) {
        await localDataSource.cacheUserToken(result.result!);
      }

      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, String?>> loginWithApple(LoginParams params) async {
    try {
      // Call the network data source for Apple Sign-In
      final result = await networkDataSource.loginWithApple(params);

      // Cache the token locally
      if (result.result != null) {
        await localDataSource.cacheUserToken(result.result!);
      }

      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, String?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final result = await networkDataSource.verifySmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Cache the token locally
      if (result.result != null) {
        await localDataSource.cacheUserToken(result.result!);
      }
      
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, String?>> getCachedToken() async {
    try {
      final token = await localDataSource.getCachedUserToken();
      return Right(token);
    } catch (e) {
      return Left(ServerFailure(e.toString(), 0));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearCachedUserToken();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString(), 0));
    }
  }
}
