import 'package:flutter/material.dart';

enum AppRoute {
  home('/'),
  login('/login'),
  onboarding('/onboarding'),
  completeRegistration('/complete-registration'),
  bar('/bar/:barId'),
  promotion('/promotion/:promotionId'),
  orders('/orders'),
  order('/order/:orderId'),
  orderDetail('/order_detail/:orderId'),
  createBar('/create-bar'),
  checkin('/checkin'),
  cart('/cart'),
  businessDashboard('/business'),
  businessCashier('/business/cashier'),
  businessMenu('/business/menu'),
  businessMenuReader('/business/menu-reader'),
  businessCampaigns('/business/campaigns'),
  businessCampaignAnalytics('/business/campaign/:campaignId/analytics'),
  businessStaff('/business/staff'),
  businessSubscriptionPlans('/business/subscription-plans'),
  ;

  final String path;
  const AppRoute(this.path);

  String get name => toString().split('.').last;
}

extension AppRouteX on AppRoute {
  static AppRoute? fromLocation(String location) {
    final cleanLocation = location.split('?').first;
    
    for (final route in AppRoute.values) {
      if (_matchesPath(route.path, cleanLocation)) {
        return route;
      }
    }
    return null;
  }

  static bool _matchesPath(String pattern, String location) {
    final patternSegments = pattern.split('/').where((s) => s.isNotEmpty).toList();
    final locationSegments = location.split('/').where((s) => s.isNotEmpty).toList();
    
    if (patternSegments.length != locationSegments.length) return false;
    
    for (int i = 0; i < patternSegments.length; i++) {
      final pSeg = patternSegments[i];
      final lSeg = locationSegments[i];
      
      if (pSeg.startsWith(':')) continue;
      if (pSeg != lSeg) return false;
    }
    return true;
  }
}

class BusinessNavigationItem {
  final IconData icon;
  final String label;
  final AppRoute route;

  const BusinessNavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

List<BusinessNavigationItem> buildBusinessNavItems({
  required bool canEditMenu,
  required bool canManageAds,
  required bool canManageStaff,
}) {
  final items = <BusinessNavigationItem>[
    const BusinessNavigationItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: AppRoute.businessDashboard,
    ),
    const BusinessNavigationItem(
      icon: Icons.point_of_sale,
      label: 'Cashier',
      route: AppRoute.businessCashier,
    ),
  ];

  if (canEditMenu) {
    items.add(const BusinessNavigationItem(
      icon: Icons.restaurant_menu,
      label: 'Menu',
      route: AppRoute.businessMenu,
    ));
  }

  if (canManageAds) {
    items.add(const BusinessNavigationItem(
      icon: Icons.campaign,
      label: 'Campaigns',
      route: AppRoute.businessCampaigns,
    ));
  }

  if (canManageStaff) {
    items.add(const BusinessNavigationItem(
      icon: Icons.people,
      label: 'Staff',
      route: AppRoute.businessStaff,
    ));
  }

  return items;
}
