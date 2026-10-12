import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/data/data_sources/local/login_local_datasource.dart';
import 'package:barz/features/authentication/data/data_sources/login_network_datasource.dart';
import 'package:barz/features/authentication/data/repositories/login_repository.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_network.dart';

Future<void> initLoginInjections() async {
  // Register FirebaseAuth
  getItInjector.registerLazySingleton<FirebaseAuth>(
    () => FirebaseAuth.instance,
  );

  // Register LoginNetworkDataSource
  getItInjector.registerLazySingleton<LoginNetworkDataSource>(
    () => LoginNetworkDataSource(
      dio: DioNetwork.appAPI,
      firebaseAuth: getItInjector<FirebaseAuth>(),
    ),
  );

  // Register LoginLocalDataSource
  getItInjector.registerLazySingleton<LoginLocalDataSource>(
    () => LoginLocalDataSource(
      sharedPreferences: getItInjector<SharedPreferences>(),
    ),
  );

  // Register LoginRepositoryImpl
  getItInjector.registerLazySingleton<AbstractLoginRepository>(
    () => LoginRepositoryImpl(
      networkDataSource: getItInjector<LoginNetworkDataSource>(),
      localDataSource: getItInjector<LoginLocalDataSource>(),
    ),
  );

  // Register LoginUsecase
  getItInjector.registerLazySingleton<LoginUsecase>(
    () => LoginUsecase(repository: getItInjector<AbstractLoginRepository>()),
  );

  // Register LoginBloc
  getItInjector.registerFactory<LoginBloc>(
    () => LoginBloc(
      loginUseCase: getItInjector<LoginUsecase>(),
      firebaseAuth: getItInjector<FirebaseAuth>(),
    ),
  );
}
