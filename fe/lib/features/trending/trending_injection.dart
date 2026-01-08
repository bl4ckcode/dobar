import 'package:get_it/get_it.dart';
import 'package:barz/core/network/dio_network.dart';
import 'data/data_sources/trending_network_datasource.dart';
import 'data/trending_repository_impl.dart';
import 'domain/repository/trending_repository.dart';
import 'presentation/bloc/trending_bloc.dart';

/// Register trending feature dependencies.
void registerTrendingFeature(GetIt getIt) {
  // Datasource
  getIt.registerLazySingleton<TrendingNetworkDatasource>(
    () => TrendingNetworkDatasource(dio: DioNetwork.appAPI),
  );

  // Repository
  getIt.registerLazySingleton<TrendingRepository>(
    () => TrendingRepositoryImpl(getIt<TrendingNetworkDatasource>()),
  );

  // BLoC - factory so we get fresh instances
  getIt.registerFactory<TrendingBloc>(
    () => TrendingBloc(getIt<TrendingRepository>()),
  );
}
