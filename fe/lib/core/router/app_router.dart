import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/ui/shell/app_shell.dart';
import 'package:barz/ui/business/business_root_shell.dart';
import 'package:barz/ui/business/business_dashboard_page.dart';
import 'package:barz/ui/business/cashier_page.dart';
import 'package:barz/ui/business/menu_management_page.dart';
import 'package:barz/ui/business/staff_management_page.dart';
import 'package:barz/features/advertising/presentation/pages/campaigns_page.dart';
import 'package:barz/features/bars/presentation/pages/create_bar/create_bar_page.dart';
import 'package:barz/features/advertising/presentation/pages/campaign_analytics_page.dart';
import 'package:barz/features/advertising/presentation/pages/subscription_plans_page.dart';
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
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_reader_page.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _businessShellNavigatorKey = GlobalKey<NavigatorState>();

const _publicRoutes = {'/login'};

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) async {
    final isAuthenticated = await DioNetwork.isAuthenticated();
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(currentPath);

    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    if (isAuthenticated && currentPath == '/login') {
      return '/';
    }

    return null;
  },
  routes: [
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
        return OnboardingPage(phoneNumber: extra?['phone']);
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
      path: '/',
      name: 'appShell',
      builder: (context, state) => const AppShell(),
    ),
    ShellRoute(
      navigatorKey: _businessShellNavigatorKey,
      builder: (context, state, child) => BlocProvider.value(
        value: getItInjector<SessionBloc>(),
        child: BusinessRootShell(child: child),
      ),
      routes: [
        GoRoute(
          path: AppRoute.businessDashboard.path,
          name: AppRoute.businessDashboard.name,
          builder: (context, state) => const BusinessDashboardPage(),
        ),
        GoRoute(
          path: AppRoute.businessCashier.path,
          name: AppRoute.businessCashier.name,
          builder: (context, state) => const CashierPage(),
        ),
        GoRoute(
          path: AppRoute.businessMenu.path,
          name: AppRoute.businessMenu.name,
          builder: (context, state) => const MenuManagementPage(),
        ),
        GoRoute(
          path: AppRoute.businessMenuReader.path,
          name: AppRoute.businessMenuReader.name,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final barId = extra?['barId'] as int? ?? 0;
            final menuId = extra?['menuId'] as int? ?? 0;
            return BlocProvider(
              create: (_) => getItInjector<MenuReaderBloc>(),
              child: MenuReaderPage(barId: barId, menuId: menuId),
            );
          },
        ),
        GoRoute(
          path: AppRoute.businessCampaigns.path,
          name: AppRoute.businessCampaigns.name,
          builder: (context, state) => const CampaignsPage(),
        ),
        GoRoute(
          path: AppRoute.businessCampaignAnalytics.path,
          name: AppRoute.businessCampaignAnalytics.name,
          builder: (context, state) {
            final campaignId = int.parse(state.pathParameters['campaignId']!);
            return CampaignAnalyticsPage(campaignId: campaignId);
          },
        ),
        GoRoute(
          path: AppRoute.businessStaff.path,
          name: AppRoute.businessStaff.name,
          builder: (context, state) => const StaffManagementPage(),
        ),
        GoRoute(
          path: AppRoute.businessSubscriptionPlans.path,
          name: AppRoute.businessSubscriptionPlans.name,
          builder: (context, state) => const SubscriptionPlansPage(),
        ),
      ],
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
      builder: (context, state) => const CreateBarPage(),
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
