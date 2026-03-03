import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/partners/data/data_sources/partners_network_datasource.dart';
import 'package:barz/features/partners/domain/repositories/abstract_partners_repository.dart';
import 'package:dartz/dartz.dart';

import '../../domain/models/partner/partner_menu_model.dart';
import '../../domain/models/partner/partners_base_model.dart';
import '../../domain/models/partner/partners_params.dart';
import '../data_sources/local/partners_local_datasource.dart';

class PartnersRepositoryImpl extends AbstractPartnersRepository {
  final PartnersNetworkDataSource networkDataSource;
  final PartnersLocalDatasource localDataSource;

  PartnersRepositoryImpl({
    required this.networkDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<PartnersBaseModel>>> getPartners(
    PartnersParams params,
  ) async {
    try {
      final result = await networkDataSource.getPartners(params);
      // Assuming result.data is of type List<PartnersBaseModel>
      return Right(result.result ?? []);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<PartnerMenu>>> getPartnerMenus(int barId) async {
    try {
      final result = await networkDataSource.getPartnerMenus(barId);
      // Assuming result.data is of type List<PartnerMenu>
      return Right(result.result ?? []);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
