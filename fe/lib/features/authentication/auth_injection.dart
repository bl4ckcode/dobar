import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/data/data_sources/abstract_login_api.dart';
import 'package:barz/features/authentication/data/data_sources/login_api.dart';
import 'package:barz/features/authentication/data/repositories/login_repository.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';

initLoginInjections() {
  getItInjector
      .registerSingleton<AbstractLoginApi>(LoginApi(DioNetwork.appAPI));
  getItInjector.registerSingleton<AbstractLoginRepository>(
      LoginRepositoryImpl(getItInjector()));
  // getItInjector.registerSingleton<HomeSharedPrefs>(HomeSharedPrefs(getItInjector()));
  getItInjector.registerSingleton<LoginUsecase>(LoginUsecase(getItInjector()));
}
