import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/services/websocket/websocket_service.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/services/offline/offline.dart';
import 'package:barz/features/orders/data/data_sources/live_orders_remote_data_source.dart';
import 'package:barz/features/orders/data/data_sources/order_network_datasource.dart';
import 'package:barz/features/orders/data/data_sources/order_local_datasource.dart';
import 'package:barz/features/orders/data/repositories/live_orders_repository_impl.dart';
import 'package:barz/features/orders/data/repositories/order_repository_impl.dart';
import 'package:barz/features/orders/data/sync/order_sync_executor.dart';
import 'package:barz/features/orders/domain/repositories/abstract_order_repository.dart';
import 'package:barz/features/orders/domain/usecases/live_orders_usecases.dart';
import 'package:barz/features/orders/domain/usecases/order_usecase.dart';
import 'package:barz/features/orders/presentation/bloc/live_orders_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

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

  getItInjector.registerLazySingleton<LiveOrdersRemoteDataSource>(
    () => LiveOrdersRemoteDataSourceImpl(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<LiveOrdersRepository>(
    () => LiveOrdersRepositoryImpl(
      remoteDataSource: getItInjector<LiveOrdersRemoteDataSource>(),
      connectivityService: getItInjector<ConnectivityService>(),
    ),
  );

  getItInjector.registerLazySingleton<GetLiveOrdersUseCase>(
    () => GetLiveOrdersUseCase(getItInjector<LiveOrdersRepository>()),
  );

  getItInjector.registerLazySingleton<UpdateLiveOrderStatusUseCase>(
    () => UpdateLiveOrderStatusUseCase(getItInjector<LiveOrdersRepository>()),
  );

  getItInjector.registerFactoryAsync<LiveOrdersBloc>(() async {
    final sessionBloc = getItInjector<SessionBloc>();
    final sessionState = sessionBloc.state;

    final wsBaseUrl = ApiEndpoints.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    String wsPath = '/ws/bar/0/orders';
    if (sessionState is SessionReady &&
        sessionState.session.activeBar != null) {
      wsPath = '/ws/bar/${sessionState.session.activeBar!.barId}/orders';
    }

    final token = await getItInjector<TokenStorageService>().getAccessToken();

    final wsService = WebSocketService(
      baseUrl: wsBaseUrl,
      path: wsPath,
      token: token,
    );

    return LiveOrdersBloc(
      getLiveOrdersUseCase: getItInjector<GetLiveOrdersUseCase>(),
      updateLiveOrderStatusUseCase:
          getItInjector<UpdateLiveOrderStatusUseCase>(),
      webSocketService: wsService,
    );
  });
}
