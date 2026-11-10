import 'package:get_it/get_it.dart';
import 'package:barz/features/venues/data/venue_repository_impl.dart';
import 'package:barz/features/venues/domain/venue_repository.dart';
import 'package:barz/core/session/shell_session.dart';
import 'package:barz/core/network/dio_network.dart';
import 'data/datasources/home_datasource.dart';
import 'data/repositories/home_repository.dart';
import 'data/repositories/home_repository_impl.dart';
import 'presentation/bloc/home_bloc.dart';

void registerHomeFeature(GetIt getIt) {
  if (!getIt.isRegistered<ShellSession>()) {
    getIt.registerLazySingleton<ShellSession>(ShellSession.new);
  }

  // Datasource
  getIt.registerLazySingleton<HomeDatasource>(
    () => HomeDatasourceImpl(dio: DioNetwork.appAPI),
  );

  // Repository
  getIt.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(datasource: getIt<HomeDatasource>()),
  );

  getIt.registerLazySingleton<VenueRepository>(
    () => VenueRepositoryImpl(dio: DioNetwork.appAPI),
  );

  // Bloc
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(getIt<HomeRepository>(), getIt<ShellSession>()),
  );
}
