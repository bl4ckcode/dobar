import 'dart:async';
import 'package:barz/features/menus/data/datasource/menu_network_socket_service.dart';
import 'package:barz/features/menus/domain/repositories/abstract_menus_repository.dart';
import 'package:barz/features/partners/domain/models/partner/product.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/network/error/failures.dart';

class MenusRepositoryImpl implements AbstractMenusRepository {
  @override
  Stream<Either<Failure, List<Product>>> subscribeToMenuUpdates(int barId) {
    final socketService = MenuSocketService(barId);

    return socketService.menuStream.map((items) {
      return right<Failure, List<Product>>(items);
    }).handleError((error) {
      return left<Failure, List<Product>>(ServerFailure(
        error.toString(),
        500,
      ));
    });
  }
}
