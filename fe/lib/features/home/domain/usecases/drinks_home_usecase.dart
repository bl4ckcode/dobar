import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/partners/domain/models/partner/partners_base_model.dart';
import 'package:barz/features/partners/domain/repositories/abstract_partners_repository.dart';
import 'package:dartz/dartz.dart';

import '../../../partners/domain/models/partner/partners_params.dart';

class DrinksHomeUseCase {
  final AbstractPartnersRepository repository;

  DrinksHomeUseCase({required this.repository});

  Future<Either<Failure, List<PartnersBaseModel>>> getPartners(PartnersParams params) async {
    return await repository.getPartners(params);
  }
}