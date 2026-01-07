import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/ui/shell/app_shell.dart';
import 'package:barz/ui/screens/create_bar_screen.dart';
import 'package:barz/features/bars/presentation/pages/bar_detail_page.dart';
import 'package:barz/features/promotions/presentation/pages/promotion_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/order_tracking_page.dart';
import 'package:barz/features/orders/presentation/pages/order_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/orders_page.dart';
import 'package:barz/features/checkin/presentation/pages/checkin_page.dart';
import 'package:barz/features/cart/presentation/pages/cart_page.dart';
import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/authentication/presentation/pages/complete_registration_page.dart';
import 'package:barz/features/onboarding/presentation/pages/onboarding_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Route names for easy navigation
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String completeRegistration = '/complete-registration';
  static const String bar = '/bar/:barId';
  static const String promotion = '/promotion/:promotionId';
  static const String orders = '/orders';
  static const String order = '/order/:orderId';
  static const String orderDetail = '/order_detail/:orderId';
  static const String createBar = '/create-bar';
  static const String checkin = '/checkin';
  static const String cart = '/cart';
}

/// Routes that don't require authentication
const _publicRoutes = {'/login'};

/// Routes that require auth but not complete profile (e.g., registration/onboarding flow)
const _authOnlyRoutes = {'/complete-registration', '/onboarding'};

// TODO(router): Use _authOnlyRoutes in redirect when profile completion check is implemented

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) async {
    final isAuthenticated = await DioNetwork.isAuthenticated();
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(currentPath);

    // If not authenticated and trying to access protected route -> redirect to login
    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    // If authenticated and on login page -> redirect to home
    if (isAuthenticated && currentPath == '/login') {
      return '/';
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        return OnboardingPage(
          phoneNumber: extra?['phone'],
        );
      },
    ),
    GoRoute(
      path: '/complete-registration',
      name: 'completeRegistration',
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        return CompleteRegistrationPage(
          prefilledEmail: extra?['email'],
          prefilledName: extra?['name'],
          prefilledPhone: extra?['phone'],
        );
      },
    ),
    GoRoute(
      path: '/bar/:barId',
      name: 'bar',
      builder: (context, state) {
        final barId = int.parse(state.pathParameters['barId']!);
        return BarDetailPage(barId: barId);
      },
    ),
    GoRoute(
      path: '/promotion/:promotionId',
      name: 'promotion',
      builder: (context, state) {
        final promotionId = int.parse(state.pathParameters['promotionId']!);
        return PromotionDetailPage(promotionId: promotionId);
      },
    ),
    GoRoute(
      path: '/orders',
      name: 'orders',
      builder: (context, state) => const OrdersPage(),
    ),
    GoRoute(
      path: '/order/:orderId',
      name: 'order',
      builder: (context, state) {
        final orderId = int.parse(state.pathParameters['orderId']!);
        return OrderTrackingPage(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/order_detail/:orderId',
      name: 'orderDetail',
      builder: (context, state) {
        final orderId = int.parse(state.pathParameters['orderId']!);
        return OrderDetailPage(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/create-bar',
      name: 'createBar',
      builder: (context, state) => const CreateBarScreen(),
    ),
    GoRoute(
      path: '/checkin',
      name: 'checkin',
      builder: (context, state) => const CheckinPage(),
    ),
    GoRoute(
      path: '/cart',
      name: 'cart',
      builder: (context, state) => const CartPage(),
    ),
  ],
);
