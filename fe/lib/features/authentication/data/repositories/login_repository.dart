import 'package:barz/core/network/auth_response.dart';
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
  Future<Either<Failure, AuthResponse?>> completeLoginWithBackend(User? user) async {
    try {
      final result = await networkDataSource.completeLoginWithBackend(user);
      if (result.result != null) {
        await localDataSource.cacheTokens(
          result.result!.accessToken,
          result.result!.refreshToken,
        );
      }
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, AuthResponse?>> loginWithGoogle(LoginParams params) async {
    try {
      final result = await networkDataSource.loginWithGoogle(params);
      if (result.result != null) {
        await localDataSource.cacheTokens(
          result.result!.accessToken,
          result.result!.refreshToken,
        );
      }
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, AuthResponse?>> loginWithApple(LoginParams params) async {
    try {
      final result = await networkDataSource.loginWithApple(params);
      if (result.result != null) {
        await localDataSource.cacheTokens(
          result.result!.accessToken,
          result.result!.refreshToken,
        );
      }
      return Right(result.result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, AuthResponse?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final result = await networkDataSource.verifySmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      if (result.result != null) {
        await localDataSource.cacheTokens(
          result.result!.accessToken,
          result.result!.refreshToken,
        );
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
      await networkDataSource.logout();
      await localDataSource.clearCachedTokens();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString(), 0));
    }
  }
}
