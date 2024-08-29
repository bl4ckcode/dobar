import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractloginRepository {
  Future<Either<Failure, HomeModel?>> login(LoginParams params);
}
