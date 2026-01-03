/// Defines all possible permissions in the Barz app.
/// 
/// Permissions follow a resource:action format.
/// These are used to control access to specific features based on user role.
enum Permission {
  // Bar permissions
  barView('bar:view'),
  barEdit('bar:edit'),
  barDelete('bar:delete'),
  
  // Menu permissions
  menuView('menu:view'),
  menuEdit('menu:edit'),
  
  // Order permissions
  orderView('order:view'),
  orderProcess('order:process'),
  orderCancel('order:cancel'),
  
  // Staff permissions
  staffView('staff:view'),
  staffManage('staff:manage'),
  
  // Billing/Financial permissions
  billingView('billing:view'),
  billingManage('billing:manage'),
  
  // Ads/Promotions permissions
  adsView('ads:view'),
  adsManage('ads:manage'),
  
  // Analytics permissions
  analyticsView('analytics:view'),
  analyticsExport('analytics:export'),
  ;

  final String value;
  const Permission(this.value);

  static Permission? fromString(String value) {
    try {
      return Permission.values.firstWhere(
        (p) => p.value == value,
      );
    } catch (_) {
      return null;
    }
  }

  static Set<Permission> fromStringList(List<String> values) {
    return values
        .map((v) => Permission.fromString(v))
        .whereType<Permission>()
        .toSet();
  }
}

/// Default permissions for each role
extension BarRolePermissions on Permission {
  static Set<Permission> forRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Permission.values.toSet();
      case 'admin':
        return Permission.values.toSet()..remove(Permission.barDelete);
      case 'manager':
        return {
          Permission.barView,
          Permission.menuView,
          Permission.menuEdit,
          Permission.orderView,
          Permission.orderProcess,
          Permission.orderCancel,
          Permission.staffView,
          Permission.analyticsView,
          Permission.adsView,
        };
      case 'cashier':
        return {
          Permission.barView,
          Permission.menuView,
          Permission.orderView,
          Permission.orderProcess,
        };
      case 'staff':
        return {
          Permission.barView,
          Permission.menuView,
          Permission.orderView,
        };
      default:
        return {};
    }
  }
}
