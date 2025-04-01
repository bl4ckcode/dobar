import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractLoginRepository {
  Future<Either<Failure, String?>> loginWithPhone(LoginParams params);

  Future<Either<Failure, String?>> loginWithGoogle(LoginParams params);

  Future<Either<Failure, String?>> loginWithApple(LoginParams params);

  Future<Either<Failure, String?>> loginWithFacebook(LoginParams params);

  Future<Either<Failure, String?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<Either<Failure, String?>> getCachedToken();

  Future<Either<Failure, void>> logout();
}
