import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractLoginRepository {
  Future<Either<Failure, String?>> login(LoginParams params);
}
