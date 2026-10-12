import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:barz/core/services/offline/hive_storage_service.dart';
import 'package:barz/core/services/offline/connectivity_service.dart';

const String backgroundSyncTask = 'com.barz.backgroundSync';
const String immediateOrderSyncTask = 'com.barz.immediateOrderSync';
const String cleanupCacheTask = 'com.barz.cleanupCache';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundWorker] Executing task: $taskName');

    try {
      await HiveStorageService().initialize();

      switch (taskName) {
        case backgroundSyncTask:
          return await _executeBackgroundSync();

        case immediateOrderSyncTask:
          return await _executeImmediateOrderSync(inputData);

        case cleanupCacheTask:
          return await _executeCleanupCache();

        default:
          debugPrint('[BackgroundWorker] Unknown task: $taskName');
          return true;
      }
    } catch (e) {
      debugPrint('[BackgroundWorker] Task $taskName failed: $e');
      return false;
    }
  });
}

Future<bool> _executeBackgroundSync() async {
  final connectivity = ConnectivityService();
  await connectivity.initialize();

  if (!connectivity.isOnline) {
    debugPrint('[BackgroundWorker] Offline - skipping sync');
    return true;
  }

  final storage = HiveStorageService();
  final pendingTasks = storage.getPendingSyncTasks();

  if (pendingTasks.isEmpty) {
    debugPrint('[BackgroundWorker] No pending tasks');
    return true;
  }

  debugPrint('[BackgroundWorker] Processing ${pendingTasks.length} tasks');

  for (final task in pendingTasks) {
    try {
      final success = await _processSyncTask(task);
      if (success) {
        await storage.markSyncTaskCompleted(task.id);
      } else {
        await storage.incrementSyncTaskRetry(task.id);
      }
    } catch (e) {
      await storage.incrementSyncTaskRetry(task.id);
      debugPrint('[BackgroundWorker] Task ${task.id} failed: $e');
    }
  }

  await storage.clearCompletedSyncTasks();
  return true;
}

Future<bool> _processSyncTask(SyncTask task) async {
  debugPrint('[BackgroundWorker] Processing: ${task.type.name}');

  switch (task.type) {
    case SyncTaskType.createOrder:
      return await _syncCreateOrder(task.payload);
    case SyncTaskType.updateOrder:
      return await _syncUpdateOrder(task.payload);
    case SyncTaskType.cancelOrder:
      return await _syncCancelOrder(task.payload);
    case SyncTaskType.payment:
      return await _syncPayment(task.payload);
  }
}

Future<bool> _syncCreateOrder(Map<String, dynamic> payload) async {
  debugPrint('[BackgroundWorker] Syncing create order: ${payload['order_id']}');
  return true;
}

Future<bool> _syncUpdateOrder(Map<String, dynamic> payload) async {
  debugPrint('[BackgroundWorker] Syncing update order: ${payload['order_id']}');
  return true;
}

Future<bool> _syncCancelOrder(Map<String, dynamic> payload) async {
  debugPrint('[BackgroundWorker] Syncing cancel order: ${payload['order_id']}');
  return true;
}

Future<bool> _syncPayment(Map<String, dynamic> payload) async {
  debugPrint('[BackgroundWorker] Syncing payment: ${payload['payment_id']}');
  return true;
}

Future<bool> _executeImmediateOrderSync(Map<String, dynamic>? inputData) async {
  if (inputData == null) return true;

  final orderId = inputData['order_id'];
  debugPrint('[BackgroundWorker] Immediate sync for order: $orderId');

  return true;
}

Future<bool> _executeCleanupCache() async {
  final storage = HiveStorageService();

  final orders = storage.getAllCachedOrders();
  final now = DateTime.now();
  int removed = 0;

  for (final order in orders) {
    final createdAt = DateTime.tryParse(order['created_at'] ?? '');
    if (createdAt != null && now.difference(createdAt).inDays > 30) {
      final orderId = order['id'] as int?;
      if (orderId != null) {
        await storage.deleteOrder(orderId);
        removed++;
      }
    }
  }

  debugPrint('[BackgroundWorker] Cleaned up $removed old orders');
  return true;
}

class BackgroundWorker {
  static final BackgroundWorker _instance = BackgroundWorker._internal();
  factory BackgroundWorker() => _instance;
  BackgroundWorker._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      debugPrint('[BackgroundWorker] Not supported on web');
      return;
    }

    await Workmanager().initialize(callbackDispatcher);

    _isInitialized = true;
    debugPrint('[BackgroundWorker] Initialized');
  }

  Future<void> registerPeriodicSync() async {
    if (kIsWeb) return;

    await Workmanager().registerPeriodicTask(
      'periodic-sync',
      backgroundSyncTask,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('[BackgroundWorker] Periodic sync registered');
  }

  Future<void> scheduleImmediateSync({int? orderId}) async {
    if (kIsWeb) return;

    await Workmanager().registerOneOffTask(
      'immediate-sync-${DateTime.now().millisecondsSinceEpoch}',
      immediateOrderSyncTask,
      inputData: orderId != null ? {'order_id': orderId} : null,
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(seconds: 5),
    );

    debugPrint('[BackgroundWorker] Immediate sync scheduled');
  }

  Future<void> scheduleCleanup() async {
    if (kIsWeb) return;

    await Workmanager().registerPeriodicTask(
      'cache-cleanup',
      cleanupCacheTask,
      frequency: const Duration(days: 1),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresCharging: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('[BackgroundWorker] Cache cleanup scheduled');
  }

  Future<void> cancelAllTasks() async {
    if (kIsWeb) return;
    await Workmanager().cancelAll();
    debugPrint('[BackgroundWorker] All tasks cancelled');
  }
}
