import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/user/data/data_sources/user_network_datasource.dart';
import 'package:barz/features/user/data/repositories/user_repository_impl.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/features/user/presentation/bloc/user_bloc.dart';

void initUserInjection() {
  getItInjector.registerLazySingleton<UserDatasource>(
    () => UserNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(getItInjector<UserDatasource>()),
  );

  getItInjector.registerLazySingleton<UserUsecase>(
    () => UserUsecase(getItInjector<UserRepository>()),
  );

  getItInjector.registerFactory<UserBloc>(
    () => UserBloc(getItInjector<UserUsecase>()),
  );
}
