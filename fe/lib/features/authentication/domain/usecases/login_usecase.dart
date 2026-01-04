import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginUsecase {
  final AbstractLoginRepository repository;

  LoginUsecase({required this.repository});

  // Phone Number Authentication
  Future<Either<Failure, String?>> complete(User? user) async {
    return await repository.completeLoginWithBackend(user);
  }

  // Google Sign-In Authentication
  Future<Either<Failure, String?>> loginWithGoogle(LoginParams params) async {
    return await repository.loginWithGoogle(params);
  }

  // Apple Sign-In Authentication
  Future<Either<Failure, String?>> loginWithApple(LoginParams params) async {
    return await repository.loginWithApple(params);
  }

  // Verify SMS Code
  Future<Either<Failure, String?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return await repository.verifySmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  // Get Cached Token
  Future<Either<Failure, String?>> getCachedToken() async {
    return await repository.getCachedToken();
  }

  // Logout
  Future<Either<Failure, void>> logout() async {
    return await repository.logout();
  }
}
