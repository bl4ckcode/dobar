import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/data/data_sources/home_impl_api.dart';
import 'package:barz/features/home/data/data_sources/local/home_shared_prefs.dart';
import 'package:barz/features/home/data/repositories/home_impl_repo.dart';
import 'package:barz/features/home/domain/repositories/abstract_home_repository.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import 'package:barz/features/home/domain/usecases/home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_bloc.dart';

import '../partners/domain/repositories/abstract_partners_repository.dart';

Future<void> initHomeInjections() async {
  // Register HomeImplApi
  getItInjector.registerSingleton<HomeImplApi>(HomeImplApi(DioNetwork.appAPI));
  // Register AbstractHomeRepository
  getItInjector.registerSingleton<AbstractHomeRepository>(HomeRepositoryImpl(getItInjector()));
  // Register HomeSharedPrefs
  getItInjector.registerSingleton<HomeSharedPrefs>(HomeSharedPrefs(getItInjector()));
  // Register HomeUseCase
  getItInjector.registerSingleton<HomeUseCase>(HomeUseCase(getItInjector()));
  // Register DrinksHomeUseCase
  getItInjector.registerLazySingleton<DrinksHomeUseCase>(
    () => DrinksHomeUseCase(
      repository: getItInjector<AbstractPartnersRepository>(),
    ),
  );
  // Register DrinksHomeBloc
  getItInjector.registerLazySingleton<DrinksHomeBloc>(
    () => DrinksHomeBloc(
      drinksHomeUseCase: getItInjector<DrinksHomeUseCase>(),
    ),
  );
}
