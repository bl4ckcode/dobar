import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:dartz/dartz.dart';

class BarUsecase {
  final AbstractBarRepository repository;

  BarUsecase({required this.repository});

  Future<Either<Failure, List<BarModel>>> getNearbyBars(
      double lat, double lng, double maxDistance) {
    return repository.getNearbyBars(lat, lng, maxDistance);
  }

  Future<Either<Failure, BarModel>> getBar(int barId) {
    return repository.getBar(barId);
  }

  Future<Either<Failure, List<MenuModel>>> getBarMenus(int barId) {
    return repository.getBarMenus(barId);
  }
}
