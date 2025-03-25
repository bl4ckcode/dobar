import 'package:barz/core/network/error/failures.dart';
import 'package:dartz/dartz.dart';

import '../models/partner/partner_menu_model.dart';
import '../models/partner/partners_base_model.dart';
import '../models/partner/partners_params.dart';

abstract class AbstractPartnersRepository {
  Future<Either<Failure, List<PartnersBaseModel>>> getPartners(
    PartnersParams params,
  );

  Future<Either<Failure, List<PartnerMenu>>> getPartnerMenus(
    int barId,
  );
}
