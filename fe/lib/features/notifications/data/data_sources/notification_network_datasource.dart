import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/notifications/domain/models/notification_model.dart';
import 'package:dio/dio.dart';

class NotificationNetworkDataSource {
  final Dio dio;

  NotificationNetworkDataSource({required this.dio});

  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notifications}',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return (response.data as List)
          .map((e) => NotificationModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to fetch notifications',
        e.response?.statusCode,
      );
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notificationRead(notificationId)}',
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to mark notification as read',
        e.response?.statusCode,
      );
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notificationsReadAll}',
      );
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to mark all as read',
        e.response?.statusCode,
      );
    }
  }
}
