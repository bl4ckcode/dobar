import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/orders/domain/models/live_order_model.dart';
import 'package:dio/dio.dart';

abstract class LiveOrdersRemoteDataSource {
  Future<List<LiveOrderModel>> getLiveOrders(int barId);
  Future<LiveOrderModel> updateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
  );
}

class LiveOrdersRemoteDataSourceImpl implements LiveOrdersRemoteDataSource {
  final Dio dio;

  LiveOrdersRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<LiveOrderModel>> getLiveOrders(int barId) async {
    try {
      final response = await dio.get(ApiEndpoints.barOrdersLive(barId));
      return (response.data as List)
          .map((json) => LiveOrderModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to fetch live orders',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<LiveOrderModel> updateOrderStatus(
    int barId,
    String orderId,
    String newStatus,
  ) async {
    try {
      final response = await dio.put(
        ApiEndpoints.barOrderStatus(barId, orderId),
        data: {'status': newStatus},
      );
      return LiveOrderModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to update order status',
        e.response?.statusCode,
      );
    }
  }
}
