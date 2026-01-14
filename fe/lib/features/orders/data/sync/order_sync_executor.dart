import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/services/offline/hive_storage_service.dart';
import 'package:barz/core/services/offline/sync_models.dart';
import 'package:barz/core/services/offline/sync_service.dart';
import 'package:barz/features/orders/data/data_sources/order_network_datasource.dart';
import 'package:barz/features/orders/data/data_sources/order_local_datasource.dart';

class OrderSyncExecutor {
  final OrderNetworkDataSource networkDataSource;
  final OrderLocalDataSource localDataSource;
  final SyncService syncService;
  
  final _conflictController = StreamController<SyncConflict>.broadcast();
  Stream<SyncConflict> get conflicts => _conflictController.stream;
  
  final List<SyncConflict> _unresolvedConflicts = [];
  List<SyncConflict> get unresolvedConflicts => List.unmodifiable(_unresolvedConflicts);

  OrderSyncExecutor({
    required this.networkDataSource,
    required this.localDataSource,
    required this.syncService,
  });

  void register() {
    syncService.registerExecutor(SyncTaskType.createOrder, _executeOrderSync);
    syncService.registerExecutor(SyncTaskType.updateOrder, _executeOrderSync);
    syncService.registerExecutor(SyncTaskType.cancelOrder, _executeOrderStatusSync);
  }

  void unregister() {
    syncService.unregisterExecutor(SyncTaskType.createOrder);
    syncService.unregisterExecutor(SyncTaskType.updateOrder);
    syncService.unregisterExecutor(SyncTaskType.cancelOrder);
  }

  Future<void> _executeOrderSync(SyncTask task) async {
    final payload = task.payload;
    final orderId = payload['order_id'] as int;
    final operation = payload['operation'] as String? ?? 'update';
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final clientTimestamp = payload['client_timestamp'] != null 
        ? DateTime.parse(payload['client_timestamp'] as String)
        : task.createdAt;

    final syncOperation = SyncOperation(
      clientId: task.id,
      orderId: orderId,
      operation: operation,
      data: data,
      clientTimestamp: clientTimestamp,
    );

    final response = await networkDataSource.syncOrders([syncOperation]);
    
    if (response.hasConflicts) {
      for (final conflict in response.conflicts) {
        _unresolvedConflicts.add(conflict);
        _conflictController.add(conflict);
        debugPrint('[OrderSyncExecutor] Conflict for order ${conflict.orderId}: ${conflict.conflictType}');
      }
      throw ConflictException(response.conflicts);
    }
    
    debugPrint('[OrderSyncExecutor] Successfully synced order $orderId');
  }

  Future<void> _executeOrderStatusSync(SyncTask task) async {
    final payload = task.payload;
    final orderId = payload['order_id'] as int;
    final newStatus = payload['status'] as String;
    
    final syncOperation = SyncOperation(
      clientId: task.id,
      orderId: orderId,
      operation: 'status_change',
      data: {'status': newStatus},
      clientTimestamp: task.createdAt,
    );

    final response = await networkDataSource.syncOrders([syncOperation]);
    
    if (response.hasConflicts) {
      for (final conflict in response.conflicts) {
        _unresolvedConflicts.add(conflict);
        _conflictController.add(conflict);
      }
      throw ConflictException(response.conflicts);
    }
    
    debugPrint('[OrderSyncExecutor] Successfully synced order status: $orderId -> $newStatus');
  }

  Future<void> resolveConflict(SyncConflict conflict, Resolution resolution) async {
    switch (resolution) {
      case Resolution.useServer:
        final freshOrder = await networkDataSource.getOrder(conflict.orderId);
        await localDataSource.cacheOrder(freshOrder);
        break;
      case Resolution.useClient:
        final syncOp = SyncOperation(
          clientId: 'resolve_${conflict.orderId}_${DateTime.now().millisecondsSinceEpoch}',
          orderId: conflict.orderId,
          operation: 'force_update',
          data: conflict.clientState,
          clientTimestamp: DateTime.now(),
        );
        await networkDataSource.syncOrders([syncOp]);
        break;
      case Resolution.merge:
        final mergedData = {...conflict.serverState, ...conflict.clientState};
        final syncOp = SyncOperation(
          clientId: 'merge_${conflict.orderId}_${DateTime.now().millisecondsSinceEpoch}',
          orderId: conflict.orderId,
          operation: 'merge',
          data: mergedData,
          clientTimestamp: DateTime.now(),
        );
        await networkDataSource.syncOrders([syncOp]);
        break;
    }
    
    _unresolvedConflicts.removeWhere((c) => c.orderId == conflict.orderId);
  }

  void dispose() {
    _conflictController.close();
  }
}

class ConflictException implements Exception {
  final List<SyncConflict> conflicts;
  ConflictException(this.conflicts);
  
  @override
  String toString() => 'ConflictException: ${conflicts.length} conflicts';
}
