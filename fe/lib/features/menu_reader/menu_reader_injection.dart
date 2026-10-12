import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/menu_reader/data/datasources/menu_reader_datasource.dart';
import 'package:barz/features/menu_reader/data/repositories/menu_reader_repository_impl.dart';
import 'package:barz/features/menu_reader/domain/repositories/menu_reader_repository.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';

Future<void> initMenuReaderInjection() async {
  getItInjector.registerLazySingleton<MenuReaderDatasource>(
    () => MenuReaderNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<MenuReaderRepository>(
    () => MenuReaderRepositoryImpl(
      datasource: getItInjector<MenuReaderDatasource>(),
      dio: DioNetwork.appAPI,
    ),
  );

  getItInjector.registerFactory<MenuReaderBloc>(
    () => MenuReaderBloc(repository: getItInjector<MenuReaderRepository>()),
  );
}
