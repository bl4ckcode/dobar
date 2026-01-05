import 'package:barz/core/network/auth_response.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginUsecase {
  final AbstractLoginRepository repository;

  LoginUsecase({required this.repository});

  Future<Either<Failure, AuthResponse?>> complete(User? user) async {
    return await repository.completeLoginWithBackend(user);
  }

  Future<Either<Failure, AuthResponse?>> loginWithGoogle(LoginParams params) async {
    return await repository.loginWithGoogle(params);
  }

  Future<Either<Failure, AuthResponse?>> loginWithApple(LoginParams params) async {
    return await repository.loginWithApple(params);
  }

  Future<Either<Failure, AuthResponse?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return await repository.verifySmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<Either<Failure, String?>> getCachedToken() async {
    return await repository.getCachedToken();
  }

  Future<Either<Failure, void>> logout() async {
    return await repository.logout();
  }
}
