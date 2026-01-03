/// Defines roles a user can have at a specific bar.
/// 
/// Hierarchy: OWNER > ADMIN > MANAGER > CASHIER > STAFF
/// 
/// Each role has specific permissions that determine what actions
/// the user can perform within that bar's context.
enum BarRole {
  owner,
  admin,
  manager,
  cashier,
  staff,
}

extension BarRoleExtension on BarRole {
  String get displayName {
    switch (this) {
      case BarRole.owner:
        return 'Owner';
      case BarRole.admin:
        return 'Administrator';
      case BarRole.manager:
        return 'Manager';
      case BarRole.cashier:
        return 'Cashier';
      case BarRole.staff:
        return 'Staff';
    }
  }

  String get description {
    switch (this) {
      case BarRole.owner:
        return 'Full control, can delete bar';
      case BarRole.admin:
        return 'Full control except ownership transfer';
      case BarRole.manager:
        return 'Day-to-day operations management';
      case BarRole.cashier:
        return 'Process orders and payments';
      case BarRole.staff:
        return 'View-only access with notifications';
    }
  }

  /// Returns the hierarchy level (lower = more permissions)
  int get hierarchyLevel {
    switch (this) {
      case BarRole.owner:
        return 0;
      case BarRole.admin:
        return 1;
      case BarRole.manager:
        return 2;
      case BarRole.cashier:
        return 3;
      case BarRole.staff:
        return 4;
    }
  }

  /// Check if this role has higher or equal privileges than another
  bool hasPrivilegeOver(BarRole other) {
    return hierarchyLevel <= other.hierarchyLevel;
  }

  static BarRole fromString(String value) {
    return BarRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => BarRole.staff,
    );
  }
}
