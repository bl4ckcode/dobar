import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/location/data/datasources/location_datasource.dart';
import 'package:barz/features/location/data/repositories/location_repository_impl.dart';
import 'package:barz/features/location/domain/repositories/location_repository.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';

void initLocationInjection() {
  getItInjector.registerLazySingleton<LocationDatasource>(
    () => LocationDatasourceImpl(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(getItInjector<LocationDatasource>()),
  );

  getItInjector.registerLazySingleton<LocationUsecase>(
    () => LocationUsecase(getItInjector<LocationRepository>()),
  );

  getItInjector.registerLazySingleton<LocationCubit>(
    () => LocationCubit(getItInjector<LocationUsecase>()),
  );
}
