import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/data/datasources/session_datasource.dart';
import 'package:barz/features/session/data/repositories/session_repository_impl.dart';
import 'package:barz/features/session/domain/repositories/session_repository.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';

import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';

Future<void> initSessionInjection() async {
  // Datasource
  getItInjector.registerLazySingleton<SessionDatasource>(
    () => SessionNetworkDatasource(dio: DioNetwork.appAPI),
  );

  // Repository
  getItInjector.registerLazySingleton<SessionRepository>(
    () => SessionRepositoryImpl(getItInjector<SessionDatasource>()),
  );

  // Usecase
  getItInjector.registerLazySingleton<SessionUsecase>(
    () => SessionUsecase(
      sessionRepository: getItInjector<SessionRepository>(),
      userRepository: getItInjector<UserRepository>(),
    ),
  );

  // Bloc - Singleton because it holds app-wide session state
  getItInjector.registerLazySingleton<SessionBloc>(
    () => SessionBloc(
      sessionUsecase: getItInjector<SessionUsecase>(),
      loginUsecase: getItInjector<LoginUsecase>(),
    ),
  );
}
