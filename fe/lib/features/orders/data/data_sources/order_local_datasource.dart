import 'package:barz/core/services/offline/hive_storage_service.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';

class OrderLocalDataSource {
  final HiveStorageService _storage;

  OrderLocalDataSource({required HiveStorageService storage})
    : _storage = storage;

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
    required int page,
    required int pageSize,
    String? status,
  }) {
    var allOrders = getCachedOrders();

    if (status != null && status.isNotEmpty) {
      allOrders = allOrders.where((o) => o.status == status).toList();
    }

    final total = allOrders.length;
    final startIndex = (page - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, total);

    final paginatedOrders = startIndex < total
        ? allOrders.sublist(startIndex, endIndex)
        : <OrderModel>[];

    return PaginatedOrders(
      orders: paginatedOrders,
      total: total,
      page: page,
      pageSize: pageSize,
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
