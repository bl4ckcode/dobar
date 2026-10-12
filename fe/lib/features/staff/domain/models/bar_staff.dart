import 'package:barz/core/rbac/rbac.dart';

/// Represents a staff member at a bar.
class BarStaff {
  final String id;
  final String name;
  final String email;
  final String phone;
  final BarRole role;
  final String? avatarUrl;

  const BarStaff({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
  });

  factory BarStaff.fromJson(Map<String, dynamic> json) {
    return BarStaff(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: BarRoleExtension.fromString(json['role'] as String? ?? 'staff'),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatar_url': avatarUrl,
    };
  }

  @override
  String toString() => 'BarStaff(id: $id, name: $name, role: ${role.name})';
}
