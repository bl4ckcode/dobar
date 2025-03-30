import 'package:barz/features/partners/data/data_sources/partners_network_datasource.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import 'package:barz/features/partners/domain/usecases/menus_usecase.dart';
import 'package:barz/features/partners/presentation/bloc/menus_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_network.dart';
import '../../core/utils/injections.dart';
import 'data/data_sources/local/partners_local_datasource.dart';
import 'data/repositories/partners_repo.dart';
import 'domain/repositories/abstract_partners_repository.dart';

Future<void> initPartnersInjection() async {
  // Register LoginNetworkDataSource
  getItInjector.registerLazySingleton<PartnersNetworkDataSource>(
    () => PartnersNetworkDataSource(dio: DioNetwork.appAPI),
  );

  // Register LoginLocalDataSource
  getItInjector.registerLazySingleton<PartnersLocalDatasource>(
    () => PartnersLocalDatasource(
      sharedPreferences: getItInjector<SharedPreferences>(),
    ),
  );

  // Register LoginRepositoryImpl
  getItInjector.registerLazySingleton<AbstractPartnersRepository>(
    () => PartnersRepositoryImpl(
      networkDataSource: getItInjector<PartnersNetworkDataSource>(),
      localDataSource: getItInjector<PartnersLocalDatasource>(),
    ),
  );

  // Register MenusUseCase
  getItInjector.registerLazySingleton<MenusUseCase>(
    () => MenusUseCase(
      repository: getItInjector<AbstractPartnersRepository>(),
    ),
  );

  // Register MenusBloc
  getItInjector.registerLazySingleton<MenusBloc>(
    () => MenusBloc(
      menusUseCase: getItInjector<MenusUseCase>(),
    ),
  );
}
