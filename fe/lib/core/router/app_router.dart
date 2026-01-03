import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/ui/shell/app_shell.dart';
import 'package:barz/ui/screens/create_bar_screen.dart';
import 'package:barz/features/bars/presentation/pages/bar_detail_page.dart';
import 'package:barz/features/promotions/presentation/pages/promotion_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/order_tracking_page.dart';
import 'package:barz/features/orders/presentation/pages/orders_page.dart';
import 'package:barz/features/checkin/presentation/pages/checkin_page.dart';
import 'package:barz/features/cart/presentation/pages/cart_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: '/bar/:barId',
      builder: (context, state) {
        final barId = int.parse(state.pathParameters['barId']!);
        return BarDetailPage(barId: barId);
      },
    ),
    GoRoute(
      path: '/promotion/:promotionId',
      builder: (context, state) {
        final promotionId = int.parse(state.pathParameters['promotionId']!);
        return PromotionDetailPage(promotionId: promotionId);
      },
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersPage(),
    ),
    GoRoute(
      path: '/order/:orderId',
      builder: (context, state) {
        final orderId = int.parse(state.pathParameters['orderId']!);
        return OrderTrackingPage(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/create-bar',
      builder: (context, state) => const CreateBarScreen(),
    ),
    GoRoute(
      path: '/checkin',
      builder: (context, state) => const CheckinPage(),
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartPage(),
    ),
  ],
);
