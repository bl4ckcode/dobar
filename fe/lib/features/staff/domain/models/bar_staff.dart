import 'package:barz/core/rbac/rbac.dart';

/// Represents a staff member at a bar.
class BarStaff {
  final int id;
  final int barId;
  final int userId;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? profilePictureUrl;
  final BarRole role;
  final Set<Permission> permissions;
  final DateTime joinedAt;
  final bool isActive;

  const BarStaff({
    required this.id,
    required this.barId,
    required this.userId,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.profilePictureUrl,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    this.isActive = true,
  });

  factory BarStaff.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'staff';
    final permissionsList = (json['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return BarStaff(
      id: json['id'] as int,
      barId: json['bar_id'] as int,
      userId: json['user_id'] as int,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      role: BarRoleExtension.fromString(roleStr),
      permissions: Permission.fromStringList(permissionsList),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bar_id': barId,
      'user_id': userId,
      'display_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'profile_picture_url': profilePictureUrl,
      'role': role.name,
      'permissions': permissions.map((p) => p.value).toList(),
      'joined_at': joinedAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  @override
  String toString() => 'BarStaff(id: $id, name: $displayName, role: ${role.name})';
}
