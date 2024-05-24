import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/data/data_sources/home_impl_api.dart';
import 'package:barz/features/home/data/data_sources/local/home_shared_prefs.dart';
import 'package:barz/features/home/data/repositories/home_impl_repo.dart';
import 'package:barz/features/home/domain/repositories/abstract_home_repository.dart';
import 'package:barz/features/home/domain/usecases/home_usecase.dart';

initHomeInjections() {
  getItInjector.registerSingleton<HomeImplApi>(HomeImplApi(DioNetwork.appAPI));
  getItInjector.registerSingleton<AbstractHomeRepository>(HomeRepositoryImpl(getItInjector()));
  getItInjector.registerSingleton<HomeSharedPrefs>(HomeSharedPrefs(getItInjector()));
  getItInjector.registerSingleton<HomeUseCase>(HomeUseCase(getItInjector()));
}