import 'package:dartz/dartz.dart';
import 'package:barz/core/error/failures.dart';
import '../../domain/models/home_model.dart';

abstract class HomeRepository {
  Future<Either<Failure, HomeModel>> getHomeData({double? lat, double? lng});
}
