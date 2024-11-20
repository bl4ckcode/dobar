import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/data/data_sources/abstract_login_api.dart';
import 'package:barz/features/authentication/data/data_sources/login_api.dart';
import 'package:barz/features/authentication/data/repositories/login_repository.dart';
import 'package:barz/features/authentication/domain/repositories/abstract_login_repository.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:firebase_auth/firebase_auth.dart';

initLoginInjections() {
  // Register FirebaseAuth as a singleton
  getItInjector.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);

  // Register LoginApi with FirebaseAuth dependency
  getItInjector.registerSingleton<AbstractLoginApi>(
      LoginApi(getItInjector<FirebaseAuth>()));

  // Register LoginRepository with LoginApi dependency
  getItInjector.registerSingleton<AbstractLoginRepository>(
      LoginRepositoryImpl(getItInjector()));

  // Register LoginUseCase with LoginRepository dependency
  getItInjector.registerSingleton<LoginUsecase>(LoginUsecase(getItInjector()));
}
