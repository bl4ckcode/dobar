import 'package:barz/core/network/auth_response.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AbstractLoginRepository {
  Future<Either<Failure, AuthResponse?>> loginWithGoogle(LoginParams params);

  Future<Either<Failure, AuthResponse?>> loginWithApple(LoginParams params);

  Future<Either<Failure, AuthResponse?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<Either<Failure, String?>> getCachedToken();

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, AuthResponse?>> completeLoginWithBackend(User? user);
}
