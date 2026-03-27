import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum AppRoute {
  home('/'),
  login('/login'),
  onboarding('/onboarding'),
  completeRegistration('/complete-registration'),
  mfaChallenge('/auth/mfa-challenge'),
  mfaSetup('/auth/mfa-setup'),
  recoveryInitiate('/auth/recovery/initiate'),
  recoveryVerify('/auth/recovery/verify'),
  bar('/bar/:barId'),
  promotion('/promotion/:promotionId'),
  orders('/orders'),
  order('/order/:orderId'),
  orderDetail('/order_detail/:orderId'),
  createBar('/create-bar'),
  checkin('/checkin'),
  cart('/cart'),
  checkout('/checkout'),
  showcase('/showcase'),
  find('/find'),
  profile('/profile'),
  businessDashboard('/business'),
  businessCashier('/business/cashier'),
  businessMenu('/business/menu'),
  businessMenuReader('/business/menu-reader'),
  businessCampaigns('/business/campaigns'),
  businessCampaignAnalytics('/business/campaign/:campaignId/analytics'),
  businessStaff('/business/staff'),
  businessSubscriptionPlans('/business/subscription-plans'),
  businessSettings('/business/settings'),
  termsOfService('/legal/terms'),
  privacyPolicy('/legal/privacy');

  final String path;
  const AppRoute(this.path);

  String get name => toString().split('.').last;

  void push(BuildContext context, {Object? extra}) {
    context.push(path, extra: extra);
  }

  void go(BuildContext context, {Object? extra}) {
    context.go(path, extra: extra);
  }

  static void pushBar(BuildContext context, int barId) {
    context.push('/bar/$barId');
  }

  static void pushPromotion(BuildContext context, int promotionId) {
    context.push('/promotion/$promotionId');
  }

  static void pushOrder(BuildContext context, int orderId) {
    context.push('/order/$orderId');
  }

  static void goOrder(BuildContext context, int orderId) {
    context.go('/order/$orderId');
  }

  static void pushOrderDetail(BuildContext context, int orderId) {
    context.push('/order_detail/$orderId');
  }

  static void pushCampaignAnalytics(BuildContext context, int campaignId) {
    context.push('/business/campaign/$campaignId/analytics');
  }

  static void pushFind(BuildContext context, {String? category}) {
    final query = category != null ? '?category=$category' : '';
    context.push('/find$query');
  }

  static void goOnboarding(BuildContext context, {String? phone}) {
    context.go('/onboarding', extra: {'phone': phone});
  }

  static void goCompleteRegistration(
    BuildContext context, {
    String? email,
    String? name,
    String? phone,
  }) {
    context.go(
      '/complete-registration',
      extra: {'email': email, 'name': name, 'phone': phone},
    );
  }
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
    final patternSegments = pattern
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final locationSegments = location
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

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
      icon: LucideIcons.layoutDashboard,
      label: 'Dashboard',
      route: AppRoute.businessDashboard,
    ),
    const BusinessNavigationItem(
      icon: LucideIcons.shoppingBag,
      label: 'Cashier',
      route: AppRoute.businessCashier,
    ),
  ];

  if (canEditMenu) {
    items.add(
      const BusinessNavigationItem(
        icon: LucideIcons.utensilsCrossed,
        label: 'Menu',
        route: AppRoute.businessMenu,
      ),
    );
  }

  if (canManageAds) {
    items.add(
      const BusinessNavigationItem(
        icon: LucideIcons.megaphone,
        label: 'Campaigns',
        route: AppRoute.businessCampaigns,
      ),
    );
  }

  if (canManageStaff) {
    items.add(
      const BusinessNavigationItem(
        icon: LucideIcons.users,
        label: 'Staff',
        route: AppRoute.businessStaff,
      ),
    );
  }

  items.add(
    const BusinessNavigationItem(
      icon: LucideIcons.settings,
      label: 'Settings',
      route: AppRoute.businessSettings,
    ),
  );

  return items;
}
