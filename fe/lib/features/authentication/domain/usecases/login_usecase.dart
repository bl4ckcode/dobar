import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/utils/usecases/usecase.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:dartz/dartz.dart';

class LoginUsecase extends UseCase<String?, LoginParams> {
  final AbstractLoginRepository repository;

  LoginUsecase({required this.repository});

  @override
  Future<Either<Failure, String?>> call(LoginParams params) async {
    return await repository.login(params);
  }

  Future<Either<Failure, String?>> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return await repository.verifySmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}
