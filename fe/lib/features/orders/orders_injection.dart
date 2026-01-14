import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/services/offline/offline.dart';
import 'package:barz/features/orders/data/data_sources/order_network_datasource.dart';
import 'package:barz/features/orders/data/data_sources/order_local_datasource.dart';
import 'package:barz/features/orders/data/repositories/order_repository_impl.dart';
import 'package:barz/features/orders/data/sync/order_sync_executor.dart';
import 'package:barz/features/orders/domain/repositories/abstract_order_repository.dart';
import 'package:barz/features/orders/domain/usecases/order_usecase.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';

Future<void> initOrdersInjection() async {
  getItInjector.registerLazySingleton<OrderNetworkDataSource>(
    () => OrderNetworkDataSource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<OrderLocalDataSource>(
    () => OrderLocalDataSource(storage: getItInjector<HiveStorageService>()),
  );

  getItInjector.registerLazySingleton<OrderSyncExecutor>(
    () => OrderSyncExecutor(
      networkDataSource: getItInjector<OrderNetworkDataSource>(),
      localDataSource: getItInjector<OrderLocalDataSource>(),
      syncService: getItInjector<SyncService>(),
    )..register(),
  );

  getItInjector.registerLazySingleton<AbstractOrderRepository>(
    () => OrderRepositoryImpl(
      networkDataSource: getItInjector<OrderNetworkDataSource>(),
      localDataSource: getItInjector<OrderLocalDataSource>(),
      connectivityService: getItInjector<ConnectivityService>(),
      syncService: getItInjector<SyncService>(),
    ),
  );

  getItInjector.registerLazySingleton<OrderUsecase>(
    () => OrderUsecase(repository: getItInjector<AbstractOrderRepository>()),
  );

  getItInjector.registerFactory<OrderBloc>(
    () => OrderBloc(orderUsecase: getItInjector<OrderUsecase>()),
  );
}
