import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/advertising/data/datasources/advertising_datasource.dart';
import 'package:barz/features/advertising/data/repositories/advertising_repository_impl.dart';
import 'package:barz/features/advertising/domain/repositories/advertising_repository.dart';
import 'package:barz/features/advertising/domain/usecases/advertising_usecase.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';

/// Initialize advertising feature dependencies.
void initAdvertisingInjection() {
  getItInjector.registerLazySingleton<AdvertisingDatasource>(
    () => AdvertisingNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<AdvertisingRepository>(
    () => AdvertisingRepositoryImpl(getItInjector<AdvertisingDatasource>()),
  );

  getItInjector.registerLazySingleton<AdvertisingUsecase>(
    () => AdvertisingUsecase(getItInjector<AdvertisingRepository>()),
  );

  getItInjector.registerFactory<AdvertisingBloc>(
    () => AdvertisingBloc(getItInjector<AdvertisingUsecase>()),
  );
}
