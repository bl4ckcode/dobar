import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/mocks/mock_bar_repository.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'package:barz/features/bars/data/repositories/bar_repository_impl.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';

const bool _useMockBars = false;

Future<void> initBarsInjection() async {
  if (_useMockBars) {
    getItInjector.registerLazySingleton<AbstractBarRepository>(
      () => MockBarRepository(),
    );
  } else {
    getItInjector.registerLazySingleton<BarNetworkDataSource>(
      () => BarNetworkDataSource(dio: DioNetwork.appAPI),
    );

    getItInjector.registerLazySingleton<AbstractBarRepository>(
      () => BarRepositoryImpl(
          networkDataSource: getItInjector<BarNetworkDataSource>()),
    );
  }

  getItInjector.registerLazySingleton<BarUsecase>(
    () => BarUsecase(repository: getItInjector<AbstractBarRepository>()),
  );

  getItInjector.registerFactory<BarBloc>(
    () => BarBloc(barUsecase: getItInjector<BarUsecase>()),
  );
}
