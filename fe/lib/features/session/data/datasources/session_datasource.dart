import 'package:barz/features/session/domain/models/pending_invitation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:dio/dio.dart';

abstract class SessionDatasource {
  Future<List<PendingInvitation>> getPendingInvitations();

  /// Fetch all bars the user has access to
  Future<List<BarAccess>> getMyBars();

  /// Accept a staff invitation using invitation code
  Future<BarAccess> acceptInvitation(String invitationCode);

  /// Preview an invitation for the authenticated user (recipient-bound details).
  /// Returns [InvitationPreview] on 200; throws [ServerException] with a
  /// category error_code on mismatched/expired/invalid codes.
  Future<InvitationPreview> previewInvitation(String invitationCode);
}

class SessionNetworkDatasource implements SessionDatasource {
  final Dio dio;

  SessionNetworkDatasource({required this.dio});

  @override
  Future<List<PendingInvitation>> getPendingInvitations() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}/me/bars/invitations/pending',
      );
      return (response.data as List)
          .map(
            (item) => PendingInvitation.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        'Failed to load invitations',
        e.response?.statusCode,
      );
    }
  }

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
      throw ServerException('Invalid bar access response', null);
    } on DioException catch (e) {
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
      final data = e.response?.data;
      throw ServerException(
        data is Map
            ? data['error_code'] ?? data['message']
            : 'Failed to accept invitation',
        e.response?.statusCode,
        details: data is Map && data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : const {},
      );
    }
  }

  @override
  Future<InvitationPreview> previewInvitation(String invitationCode) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.previewInvitation}',
        data: {'invitation_code': invitationCode},
      );
      return InvitationPreview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw ServerException(
        data is Map
            ? data['error_code'] ?? data['message']
            : 'Failed to preview invitation',
        e.response?.statusCode,
        details: data is Map && data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : const {},
      );
    }
  }
}
