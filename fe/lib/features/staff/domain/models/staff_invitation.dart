import 'package:barz/core/rbac/rbac.dart';

/// Status of a staff invitation
enum InvitationStatus { pending, accepted, expired, revoked }

extension InvitationStatusExtension on InvitationStatus {
  static InvitationStatus fromString(String value) {
    return InvitationStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => InvitationStatus.pending,
    );
  }
}

/// Represents an invitation for a user to join a bar's staff.
class StaffInvitation {
  final int id;
  final int barId;
  final String barName;
  final String? email;
  final String? phoneNumber;
  final BarRole role;
  final InvitationStatus status;
  final String? invitationCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? invitedByName;

  const StaffInvitation({
    required this.id,
    required this.barId,
    required this.barName,
    this.email,
    this.phoneNumber,
    required this.role,
    required this.status,
    this.invitationCode,
    required this.createdAt,
    required this.expiresAt,
    this.invitedByName,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == InvitationStatus.pending && !isExpired;
  bool get canAccept => isPending;

  factory StaffInvitation.fromJson(Map<String, dynamic> json) {
    return StaffInvitation(
      id: json['id'] as int,
      barId: json['bar_id'] as int,
      barName: json['bar_name'] as String? ?? 'Unknown Bar',
      email: json['email'] as String?,
      phoneNumber: json['phone'] as String?,
      role: BarRoleExtension.fromString(json['role'] as String? ?? 'staff'),
      status: InvitationStatusExtension.fromString(
        json['status'] as String? ?? 'pending',
      ),
      invitationCode: json['invitation_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      invitedByName: json['invited_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bar_id': barId,
      'bar_name': barName,
      'email': email,
      'phone': phoneNumber,
      'role': role.name,
      'status': status.name,
      'invitation_code': invitationCode,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'invited_by_name': invitedByName,
    };
  }

  @override
  String toString() =>
      'StaffInvitation(id: $id, barName: $barName, role: ${role.name}, status: ${status.name})';
}
