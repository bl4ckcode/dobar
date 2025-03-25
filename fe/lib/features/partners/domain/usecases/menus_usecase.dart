import 'package:barz/features/partners/domain/models/partner/partner_menu_model.dart';
import 'package:barz/features/partners/domain/repositories/abstract_partners_repository.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/network/error/failures.dart';

class MenusUseCase {
  final AbstractPartnersRepository repository;

  MenusUseCase({required this.repository});

  Future<Either<Failure, List<PartnerMenu>>> getPartnerMenus(int menuId) async {
    return await repository.getPartnerMenus(menuId);
  }
}
