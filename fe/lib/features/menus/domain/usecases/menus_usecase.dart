import 'package:barz/features/menus/domain/repositories/abstract_menus_repository.dart';
import 'package:barz/features/partners/domain/models/partner/product.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/network/error/failures.dart';

class MenusUseCase {
  final AbstractMenusRepository repository;

  MenusUseCase({required this.repository});

  Stream<Either<Failure, List<Product>>> subscribeToMenu(int barId) {
    return repository.subscribeToMenuUpdates(barId);
  }
}
