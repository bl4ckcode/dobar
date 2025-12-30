import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/promotions/data/datasources/promotions_datasource.dart';
import 'package:barz/features/promotions/data/repositories/promotions_repository_impl.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:barz/features/promotions/domain/usecases/promotions_usecase.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';

void initPromotionsInjection() {
  getItInjector.registerLazySingleton<PromotionsDatasource>(
    () => PromotionsNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<PromotionsRepository>(
    () => PromotionsRepositoryImpl(getItInjector<PromotionsDatasource>()),
  );

  getItInjector.registerLazySingleton<PromotionsUsecase>(
    () => PromotionsUsecase(getItInjector<PromotionsRepository>()),
  );

  getItInjector.registerFactory<PromotionsBloc>(
    () => PromotionsBloc(getItInjector<PromotionsUsecase>()),
  );
}
