import 'package:get_it/get_it.dart';
import 'package:barz/core/network/dio_network.dart';
import 'data/datasources/home_datasource.dart';
import 'data/repositories/home_repository.dart';
import 'data/repositories/home_repository_impl.dart';
import 'presentation/bloc/home_bloc.dart';

void registerHomeFeature(GetIt getIt) {
  // Datasource
  getIt.registerLazySingleton<HomeDatasource>(
    () => HomeDatasourceImpl(dio: DioNetwork.appAPI),
  );

  // Repository
  getIt.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(datasource: getIt<HomeDatasource>()),
  );

  // Bloc
  getIt.registerFactory<HomeBloc>(() => HomeBloc(getIt<HomeRepository>()));
}
