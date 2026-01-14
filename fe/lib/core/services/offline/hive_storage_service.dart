import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveStorageService {
  static final HiveStorageService _instance = HiveStorageService._internal();
  factory HiveStorageService() => _instance;
  HiveStorageService._internal();

  static const String _ordersBoxName = 'orders_cache';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _metadataBoxName = 'cache_metadata';

  late Box<Map> _ordersBox;
  late Box<Map> _syncQueueBox;
  late Box<dynamic> _metadataBox;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    _ordersBox = await Hive.openBox<Map>(_ordersBoxName);
    _syncQueueBox = await Hive.openBox<Map>(_syncQueueBoxName);
    _metadataBox = await Hive.openBox<dynamic>(_metadataBoxName);
    
    _isInitialized = true;
    debugPrint('[Hive] Storage initialized');
  }

  Future<void> cacheOrder(int orderId, Map<String, dynamic> orderData) async {
    await _ordersBox.put(orderId.toString(), orderData);
    await _updateCacheTimestamp('order_$orderId');
    debugPrint('[Hive] Cached order $orderId');
  }

  Future<void> cacheOrders(List<Map<String, dynamic>> orders) async {
    final Map<String, Map> entries = {};
    for (final order in orders) {
      final id = order['id']?.toString();
      if (id != null) {
        entries[id] = order;
      }
    }
    await _ordersBox.putAll(entries);
    await _updateCacheTimestamp('orders_list');
    debugPrint('[Hive] Cached ${orders.length} orders');
  }

  Map<String, dynamic>? getOrder(int orderId) {
    final data = _ordersBox.get(orderId.toString());
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  List<Map<String, dynamic>> getAllCachedOrders() {
    return _ordersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> deleteOrder(int orderId) async {
    await _ordersBox.delete(orderId.toString());
  }

  Future<void> clearOrdersCache() async {
    await _ordersBox.clear();
    debugPrint('[Hive] Orders cache cleared');
  }

  Future<void> addToSyncQueue(SyncTask task) async {
    await _syncQueueBox.put(task.id, task.toJson());
    debugPrint('[Hive] Added to sync queue: ${task.id} (${task.type})');
  }

  Future<void> removeFromSyncQueue(String taskId) async {
    await _syncQueueBox.delete(taskId);
  }

  List<SyncTask> getPendingSyncTasks() {
    return _syncQueueBox.values
        .map((e) => SyncTask.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => !t.completed && t.retryCount < 5)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> markSyncTaskCompleted(String taskId) async {
    final data = _syncQueueBox.get(taskId);
    if (data != null) {
      final task = SyncTask.fromJson(Map<String, dynamic>.from(data));
      await _syncQueueBox.put(taskId, task.copyWith(completed: true).toJson());
    }
  }

  Future<void> incrementSyncTaskRetry(String taskId) async {
    final data = _syncQueueBox.get(taskId);
    if (data != null) {
      final task = SyncTask.fromJson(Map<String, dynamic>.from(data));
      await _syncQueueBox.put(
        taskId, 
        task.copyWith(retryCount: task.retryCount + 1).toJson(),
      );
    }
  }

  Future<void> clearCompletedSyncTasks() async {
    final completed = _syncQueueBox.values
        .map((e) => SyncTask.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.completed)
        .map((t) => t.id)
        .toList();
    
    for (final id in completed) {
      await _syncQueueBox.delete(id);
    }
    debugPrint('[Hive] Cleared ${completed.length} completed sync tasks');
  }

  Future<void> _updateCacheTimestamp(String key) async {
    await _metadataBox.put('cache_time_$key', DateTime.now().toIso8601String());
  }

  DateTime? getCacheTimestamp(String key) {
    final timestamp = _metadataBox.get('cache_time_$key') as String?;
    return timestamp != null ? DateTime.tryParse(timestamp) : null;
  }

  bool isCacheStale(String key, {Duration maxAge = const Duration(minutes: 5)}) {
    final timestamp = getCacheTimestamp(key);
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > maxAge;
  }

  Future<void> dispose() async {
    await _ordersBox.close();
    await _syncQueueBox.close();
    await _metadataBox.close();
  }
}

enum SyncTaskType { createOrder, updateOrder, cancelOrder, payment }

class SyncTask {
  final String id;
  final SyncTaskType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final bool completed;
  final String? errorMessage;

  SyncTask({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.completed = false,
    this.errorMessage,
  });

  factory SyncTask.fromJson(Map<String, dynamic> json) {
    return SyncTask(
      id: json['id'] as String,
      type: SyncTaskType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SyncTaskType.createOrder,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'completed': completed,
      'error_message': errorMessage,
    };
  }

  SyncTask copyWith({
    String? id,
    SyncTaskType? type,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    bool? completed,
    String? errorMessage,
  }) {
    return SyncTask(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      completed: completed ?? this.completed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
