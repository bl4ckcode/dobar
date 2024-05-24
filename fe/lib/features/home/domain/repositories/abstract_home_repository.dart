import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractHomeRepository {
  Future<Either<Failure, HomeModel?>> getHome(HomeParams params);
}
