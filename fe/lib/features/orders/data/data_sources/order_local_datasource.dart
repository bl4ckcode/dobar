import 'package:barz/core/services/offline/hive_storage_service.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';

class OrderLocalDataSource {
  final HiveStorageService _storage;

  OrderLocalDataSource({required this._storage});

  Future<void> cacheOrder(OrderModel order) async {
    await _storage.cacheOrder(order.id, order.toJson());
  }

  Future<void> cacheOrders(List<OrderModel> orders) async {
    final jsonOrders = orders.map((o) => o.toJson()).toList();
    await _storage.cacheOrders(jsonOrders);
  }

  OrderModel? getOrder(int orderId) {
    final json = _storage.getOrder(orderId);
    if (json == null) return null;
    return OrderModel.fromJson(json);
  }

  List<OrderModel> getCachedOrders() {
    final jsonOrders = _storage.getAllCachedOrders();
    return jsonOrders.map((json) => OrderModel.fromJson(json)).toList();
  }

  PaginatedOrders getCachedOrdersPaginated({
    String? cursor,
    int limit = 20,
    String? status,
  }) {
    var allOrders = getCachedOrders();
    allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (status != null && status.isNotEmpty) {
      allOrders = allOrders.where((o) => o.status == status).toList();
    }

    int startIndex = 0;
    if (cursor != null) {
      final cursorIndex = int.tryParse(cursor);
      if (cursorIndex != null) startIndex = cursorIndex;
    }

    final endIndex = (startIndex + limit).clamp(0, allOrders.length);
    final pageOrders = startIndex < allOrders.length
        ? allOrders.sublist(startIndex, endIndex)
        : <OrderModel>[];

    final hasMore = endIndex < allOrders.length;
    final nextCursor = hasMore ? endIndex.toString() : null;

    return PaginatedOrders(
      orders: pageOrders,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    final order = getOrder(orderId);
    if (order != null) {
      final updatedJson = order.toJson();
      updatedJson['status'] = newStatus;
      updatedJson['updated_at'] = DateTime.now().toIso8601String();
      await _storage.cacheOrder(orderId, updatedJson);
    }
  }

  Future<void> deleteOrder(int orderId) async {
    await _storage.deleteOrder(orderId);
  }

  Future<void> clearCache() async {
    await _storage.clearOrdersCache();
  }

  bool isCacheStale({Duration maxAge = const Duration(minutes: 5)}) {
    return _storage.isCacheStale('orders_list', maxAge: maxAge);
  }

  DateTime? getLastCacheTime() {
    return _storage.getCacheTimestamp('orders_list');
  }
}
