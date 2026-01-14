import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/services/offline/connectivity_service.dart';
import 'package:barz/core/services/offline/hive_storage_service.dart';

enum SyncStatus { idle, syncing, completed, failed }

class SyncEvent {
  final String taskId;
  final SyncTaskType type;
  final SyncStatus status;
  final String? message;
  final DateTime timestamp;

  SyncEvent({
    required this.taskId,
    required this.type,
    required this.status,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

typedef SyncTaskExecutor = Future<void> Function(SyncTask task);

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final HiveStorageService _storage = HiveStorageService();
  
  final _syncEventController = StreamController<SyncEvent>.broadcast();
  final Map<SyncTaskType, SyncTaskExecutor> _executors = {};
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _syncTimer;

  Stream<SyncEvent> get syncEvents => _syncEventController.stream;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _connectivity.registerOnReconnect(_onReconnect);
    
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => processPendingTasks(),
    );
    
    debugPrint('[SyncService] Initialized');
  }

  void registerExecutor(SyncTaskType type, SyncTaskExecutor executor) {
    _executors[type] = executor;
    debugPrint('[SyncService] Registered executor for ${type.name}');
  }

  void unregisterExecutor(SyncTaskType type) {
    _executors.remove(type);
  }

  Future<void> enqueueTask({
    required SyncTaskType type,
    required Map<String, dynamic> payload,
    String? taskId,
  }) async {
    final task = SyncTask(
      id: taskId ?? '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    
    await _storage.addToSyncQueue(task);
    
    if (_connectivity.isOnline) {
      processPendingTasks();
    }
  }

  void _onReconnect() {
    debugPrint('[SyncService] Reconnected - processing pending tasks');
    processPendingTasks();
  }

  Future<void> processPendingTasks() async {
    if (_isSyncing) return;
    if (!_connectivity.isOnline) {
      debugPrint('[SyncService] Offline - skipping sync');
      return;
    }

    _isSyncing = true;
    final tasks = _storage.getPendingSyncTasks();
    
    if (tasks.isEmpty) {
      debugPrint('[SyncService] No pending tasks');
      _isSyncing = false;
      return;
    }

    debugPrint('[SyncService] Processing ${tasks.length} pending tasks');

    for (final task in tasks) {
      final executor = _executors[task.type];
      
      if (executor == null) {
        debugPrint('[SyncService] No executor for ${task.type.name}');
        continue;
      }

      _emitEvent(task.id, task.type, SyncStatus.syncing);

      try {
        await executor(task);
        await _storage.markSyncTaskCompleted(task.id);
        _emitEvent(task.id, task.type, SyncStatus.completed);
        debugPrint('[SyncService] Task ${task.id} completed');
      } catch (e) {
        await _storage.incrementSyncTaskRetry(task.id);
        _emitEvent(task.id, task.type, SyncStatus.failed, message: e.toString());
        debugPrint('[SyncService] Task ${task.id} failed: $e');
        
        if (task.retryCount >= 4) {
          debugPrint('[SyncService] Task ${task.id} exceeded max retries');
        }
      }
    }

    await _storage.clearCompletedSyncTasks();
    _isSyncing = false;
  }

  void _emitEvent(String taskId, SyncTaskType type, SyncStatus status, {String? message}) {
    _syncEventController.add(SyncEvent(
      taskId: taskId,
      type: type,
      status: status,
      message: message,
    ));
  }

  int getPendingTaskCount() {
    return _storage.getPendingSyncTasks().length;
  }

  List<SyncTask> getPendingTasks() {
    return _storage.getPendingSyncTasks();
  }

  Future<void> clearAllTasks() async {
    final tasks = _storage.getPendingSyncTasks();
    for (final task in tasks) {
      await _storage.removeFromSyncQueue(task.id);
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivity.unregisterOnReconnect(_onReconnect);
    _syncEventController.close();
  }
}
