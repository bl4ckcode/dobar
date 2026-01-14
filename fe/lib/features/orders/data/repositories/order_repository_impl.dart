import 'package:flutter/foundation.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/core/services/offline/connectivity_service.dart';
import 'package:barz/core/services/offline/hive_storage_service.dart';
import 'package:barz/core/services/offline/sync_service.dart';
import 'package:barz/features/orders/data/data_sources/order_network_datasource.dart';
import 'package:barz/features/orders/data/data_sources/order_local_datasource.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/orders/domain/repositories/abstract_order_repository.dart';
import 'package:dartz/dartz.dart';

class OrderRepositoryImpl extends AbstractOrderRepository {
  final OrderNetworkDataSource networkDataSource;
  final OrderLocalDataSource localDataSource;
  final ConnectivityService connectivityService;
  final SyncService syncService;

  OrderRepositoryImpl({
    required this.networkDataSource,
    required this.localDataSource,
    required this.connectivityService,
    required this.syncService,
  });

  @override
  Future<Either<Failure, PaginatedOrders>> getMyOrders({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    final cachedOrders = localDataSource.getCachedOrdersPaginated(
      page: page,
      pageSize: pageSize,
      status: status,
    );

    if (!connectivityService.isOnline) {
      debugPrint('[OrderRepo] Offline - returning cached orders');
      if (cachedOrders.orders.isEmpty && page == 1) {
        return const Left(CacheFailure('No cached orders available'));
      }
      return Right(cachedOrders);
    }

    try {
      final result = await networkDataSource.getMyOrders(
        page: page,
        pageSize: pageSize,
        status: status,
      );
      
      if (page == 1) {
        await localDataSource.cacheOrders(result.orders);
      } else {
        for (final order in result.orders) {
          await localDataSource.cacheOrder(order);
        }
      }
      
      debugPrint('[OrderRepo] Fetched and cached ${result.orders.length} orders');
      return Right(result);
    } on ServerException catch (e) {
      debugPrint('[OrderRepo] Network error - falling back to cache: ${e.message}');
      if (cachedOrders.orders.isNotEmpty || page > 1) {
        return Right(cachedOrders);
      }
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> getOrder(int orderId) async {
    final cachedOrder = localDataSource.getOrder(orderId);

    if (!connectivityService.isOnline) {
      debugPrint('[OrderRepo] Offline - returning cached order $orderId');
      if (cachedOrder == null) {
        return const Left(CacheFailure('Order not found in cache'));
      }
      return Right(cachedOrder);
    }

    try {
      final result = await networkDataSource.getOrder(orderId);
      await localDataSource.cacheOrder(result);
      return Right(result);
    } on ServerException catch (e) {
      if (cachedOrder != null) {
        debugPrint('[OrderRepo] Network error - returning cached order');
        return Right(cachedOrder);
      }
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> getOrderTimeline(int orderId) async {
    try {
      final result = await networkDataSource.getOrderTimeline(orderId);
      await localDataSource.cacheOrder(result);
      return Right(result);
    } on ServerException catch (e) {
      final cachedOrder = localDataSource.getOrder(orderId);
      if (cachedOrder != null) {
        return Right(cachedOrder);
      }
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, OrderModel>> cancelOrder(int orderId) async {
    if (!connectivityService.isOnline) {
      debugPrint('[OrderRepo] Offline - queueing cancel order $orderId');
      await localDataSource.updateOrderStatus(orderId, 'pending_cancel');
      
      await syncService.enqueueTask(
        type: SyncTaskType.cancelOrder,
        payload: {'order_id': orderId},
      );
      
      final cachedOrder = localDataSource.getOrder(orderId);
      if (cachedOrder != null) {
        return Right(cachedOrder);
      }
      return const Left(CacheFailure('Order not found'));
    }

    try {
      final result = await networkDataSource.cancelOrder(orderId);
      await localDataSource.cacheOrder(result);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  void updateOrderFromWebSocket(int orderId, String newStatus) {
    localDataSource.updateOrderStatus(orderId, newStatus);
    debugPrint('[OrderRepo] Updated order $orderId status to $newStatus via WebSocket');
  }

  bool hasUnsyncedChanges() {
    return syncService.getPendingTaskCount() > 0;
  }

  int getUnsyncedCount() {
    return syncService.getPendingTaskCount();
  }
}

