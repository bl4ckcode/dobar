import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/utils/usecases/usecase.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';
import 'package:barz/features/home/domain/repositories/abstract_home_repository.dart';
import 'package:dartz/dartz.dart';

class HomeUseCase extends UseCase<HomeModel?, HomeParams> {
  final AbstractHomeRepository repository;

  HomeUseCase(this.repository);

  @override
  Future<Either<Failure, HomeModel?>> call(HomeParams params) async {
    final result = await repository.getHome(params);
    return result.fold(
      (l) {
        return Left(l);
      },
      (r) async {
        return Right(r);
      },
    );
  }
}
