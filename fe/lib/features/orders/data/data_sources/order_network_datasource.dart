import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/core/services/offline/sync_models.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:dio/dio.dart';

class OrderNetworkDataSource {
  final Dio dio;

  OrderNetworkDataSource({required this.dio});

  Future<PaginatedOrders> getMyOrders({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      };
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.myOrders}',
        queryParameters: queryParams,
      );
      return PaginatedOrders.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch orders',
          e.response?.statusCode);
    }
  }

  Future<OrderModel> getOrder(int orderId) async {
    try {
      final response = await dio
          .get('${ApiEndpoints.baseUrl}${ApiEndpoints.order(orderId)}');
      return OrderModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch order',
          e.response?.statusCode);
    }
  }

  Future<OrderModel> getOrderTimeline(int orderId) async {
    try {
      final response = await dio
          .get('${ApiEndpoints.baseUrl}${ApiEndpoints.orderTimeline(orderId)}');
      return OrderModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch order timeline',
          e.response?.statusCode);
    }
  }

  Future<OrderModel> cancelOrder(int orderId) async {
    try {
      final response = await dio
          .post('${ApiEndpoints.baseUrl}${ApiEndpoints.cancelOrder(orderId)}');
      return OrderModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to cancel order',
          e.response?.statusCode);
    }
  }

  Future<SyncResponse> syncOrders(List<SyncOperation> operations) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.syncOrders}',
        data: {'operations': operations.map((o) => o.toJson()).toList()},
      );
      return SyncResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to sync orders',
          e.response?.statusCode);
    }
  }
}
