import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:dio/dio.dart';
import '../../domain/models/checkin_model.dart';
import '../../domain/repositories/checkin_repository.dart';

class CheckinNetworkRepository implements CheckinRepository {
  final Dio dio;
  CheckinNetworkRepository(this.dio);

  @override
  Future<CheckinModel?> getActive() async {
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}/checkins/active');
      return response.data == null
          ? null
          : CheckinModel.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CheckinModel> confirm({
    required int barId,
    required LocationModel location,
    String? tableNumber,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}/checkins',
        data: {
          'bar_id': barId,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'measured_at': location.timestamp.toUtc().toIso8601String(),
          if (location.accuracy != null) 'accuracy_meters': location.accuracy,
          if (tableNumber?.trim().isNotEmpty == true)
            'table_number': tableNumber!.trim(),
        },
      );
      return CheckinModel.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> end() async {
    try {
      await dio.delete('${ApiEndpoints.baseUrl}/checkins/active');
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  CheckinException _failure(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final details = data['details'];
      if (details is Map) {
        if (details.containsKey('location')) {
          return const CheckinException('CHECKIN_TOO_FAR');
        }
        if (details.containsKey('measured_at')) {
          return const CheckinException('CHECKIN_LOCATION_STALE');
        }
        if (details.containsKey('table_number')) {
          return const CheckinException('CHECKIN_INVALID_LOCATION');
        }
      }
      return CheckinException('${data['error_code'] ?? 'NETWORK_ERROR'}');
    }
    return const CheckinException('NETWORK_ERROR');
  }
}
