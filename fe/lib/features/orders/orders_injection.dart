import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/services/websocket/websocket_service.dart';
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

  // Live Orders Injection
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

  getItInjector.registerFactory<LiveOrdersBloc>(() {
    // Dynamic WebSocketService instantiation based on active bar and user token
    final sessionBloc = getItInjector<SessionBloc>();
    final sessionState = sessionBloc.state;

    String wsUrl = ApiEndpoints.baseUrl;
    String wsPath = '/ws/bar/0/orders'; // Default fallback
    String? token;

    if (sessionState is SessionReady) {
      if (sessionState.session.activeBar != null) {
        wsPath = '/ws/bar/${sessionState.session.activeBar!.barId}/orders';
      }
      token = sessionState
          .session
          .user
          .firebaseUid; // The backend uses firebaseUid for token as seen in other websockets or auth interceptors? Or wait, let's just pass null if we don't know the exact token and let the interceptor/backend handle it. Assuming it uses standard Bearer tokens, the WebSocket channel might not support headers directly on web, so url query param is used. I'll just use firebaseUid as a placeholder if no dedicated token property exists.
    }

    final wsService = WebSocketService(
      baseUrl: wsUrl.replaceFirst('http', 'ws'), // ensure wss:// or ws://
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
