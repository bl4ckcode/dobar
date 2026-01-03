import 'package:barz/core/rbac/rbac.dart';

/// Represents a user's access to a specific bar.
/// 
/// This model is returned from the GET /me/bars endpoint and contains:
/// - The bar's basic info (id, name)
/// - The user's role at that bar
/// - The specific permissions granted
class BarAccess {
  final int barId;
  final String barName;
  final String? barImageUrl;
  final BarRole role;
  final Set<Permission> permissions;
  final DateTime? joinedAt;

  const BarAccess({
    required this.barId,
    required this.barName,
    this.barImageUrl,
    required this.role,
    required this.permissions,
    this.joinedAt,
  });

  /// Check if user has a specific permission for this bar
  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  /// Check if user has any of the given permissions
  bool hasAnyPermission(Set<Permission> requiredPermissions) {
    return permissions.intersection(requiredPermissions).isNotEmpty;
  }

  /// Check if user has all of the given permissions
  bool hasAllPermissions(Set<Permission> requiredPermissions) {
    return requiredPermissions.every((p) => permissions.contains(p));
  }

  /// Check if user can manage orders (cashier view access)
  bool get canManageOrders => hasPermission(Permission.orderProcess);

  /// Check if user can edit menu
  bool get canEditMenu => hasPermission(Permission.menuEdit);

  /// Check if user can manage staff
  bool get canManageStaff => hasPermission(Permission.staffManage);

  /// Check if user can view billing/financials
  bool get canViewBilling => hasPermission(Permission.billingView);

  /// Check if user can manage ads/promotions
  bool get canManageAds => hasPermission(Permission.adsManage);

  factory BarAccess.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'staff';
    final permissionsList = (json['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return BarAccess(
      barId: json['bar_id'] as int,
      barName: json['bar_name'] as String,
      barImageUrl: json['bar_image_url'] as String?,
      role: BarRoleExtension.fromString(roleStr),
      permissions: Permission.fromStringList(permissionsList),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bar_id': barId,
      'bar_name': barName,
      'bar_image_url': barImageUrl,
      'role': role.name,
      'permissions': permissions.map((p) => p.value).toList(),
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarAccess &&
          runtimeType == other.runtimeType &&
          barId == other.barId &&
          role == other.role;

  @override
  int get hashCode => barId.hashCode ^ role.hashCode;

  @override
  String toString() => 'BarAccess(barId: $barId, barName: $barName, role: ${role.name})';
}
