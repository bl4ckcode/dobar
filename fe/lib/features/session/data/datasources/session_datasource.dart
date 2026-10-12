import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:dio/dio.dart';

abstract class SessionDatasource {
  /// Fetch all bars the user has access to
  Future<List<BarAccess>> getMyBars();

  /// Accept a staff invitation using invitation code
  Future<BarAccess> acceptInvitation(String invitationCode);
}

class SessionNetworkDatasource implements SessionDatasource {
  final Dio dio;

  SessionNetworkDatasource({required this.dio});

  @override
  Future<List<BarAccess>> getMyBars() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.myBars}',
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => BarAccess.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No bars found is a valid state for clients
        return [];
      }
      throw ServerException(
        e.response?.data?['message'] ?? 'Failed to fetch bar access',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<BarAccess> acceptInvitation(String invitationCode) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.acceptInvitation}',
        data: {'invitation_code': invitationCode},
      );

      return BarAccess.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['message'] ?? 'Failed to accept invitation',
        e.response?.statusCode,
      );
    }
  }
}
