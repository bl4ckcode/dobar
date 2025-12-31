import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/data/data_sources/cart_network_datasource.dart';
import 'package:barz/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:barz/features/cart/domain/repositories/abstract_cart_repository.dart';
import 'package:barz/features/cart/domain/usecases/cart_usecase.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';

Future<void> initCartInjection() async {
  getItInjector.registerLazySingleton<CartNetworkDataSource>(
    () => CartNetworkDataSource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<AbstractCartRepository>(
    () => CartRepositoryImpl(
        networkDataSource: getItInjector<CartNetworkDataSource>()),
  );

  getItInjector.registerLazySingleton<CartUsecase>(
    () => CartUsecase(repository: getItInjector<AbstractCartRepository>()),
  );

  getItInjector.registerFactory<CartBloc>(
    () => CartBloc(cartUsecase: getItInjector<CartUsecase>()),
  );
}
