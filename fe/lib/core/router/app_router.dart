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
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/payment/presentation/pages/checkout_page.dart';
import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/authentication/presentation/pages/complete_registration_page.dart';
import 'package:barz/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_reader_page.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/promotions/presentation/screens/promotions_gallery_screen.dart';
import 'package:barz/features/legal/presentation/screens/legal_document_viewer.dart';
import 'package:barz/features/legal/domain/models/legal_document.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _businessShellNavigatorKey = GlobalKey<NavigatorState>();

const _publicRoutes = {'/login'};

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoute.home.path,
  redirect: (context, state) async {
    final isAuthenticated = await DioNetwork.isAuthenticated();
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(currentPath);

    if (!isAuthenticated && !isPublicRoute) {
      return AppRoute.login.path;
    }

    if (isAuthenticated && currentPath == AppRoute.login.path) {
      return AppRoute.home.path;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoute.login.path,
      name: AppRoute.login.name,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoute.onboarding.path,
      name: AppRoute.onboarding.name,
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        final phone = extra?['phone'] ?? extra?['phoneNumber'];
        return OnboardingPage(phoneNumber: phone);
      },
    ),
    GoRoute(
      path: AppRoute.completeRegistration.path,
      name: AppRoute.completeRegistration.name,
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
      path: AppRoute.home.path,
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
      path: AppRoute.bar.path,
      name: AppRoute.bar.name,
      builder: (context, state) {
        final barId = int.parse(state.pathParameters['barId']!);
        return BarDetailPage(barId: barId);
      },
    ),
    GoRoute(
      path: AppRoute.promotion.path,
      name: AppRoute.promotion.name,
      builder: (context, state) {
        final promotionId = int.parse(state.pathParameters['promotionId']!);
        return PromotionDetailPage(promotionId: promotionId);
      },
    ),
    GoRoute(
      path: AppRoute.orders.path,
      name: AppRoute.orders.name,
      builder: (context, state) => const OrdersPage(),
    ),
    GoRoute(
      path: AppRoute.order.path,
      name: AppRoute.order.name,
      builder: (context, state) {
        final orderId = int.parse(state.pathParameters['orderId']!);
        return OrderTrackingPage(orderId: orderId);
      },
    ),
    GoRoute(
      path: AppRoute.orderDetail.path,
      name: AppRoute.orderDetail.name,
      builder: (context, state) {
        final orderId = int.parse(state.pathParameters['orderId']!);
        return OrderDetailPage(orderId: orderId);
      },
    ),
    GoRoute(
      path: AppRoute.createBar.path,
      name: AppRoute.createBar.name,
      builder: (context, state) => const CreateBarPage(),
    ),
    GoRoute(
      path: AppRoute.checkin.path,
      name: AppRoute.checkin.name,
      builder: (context, state) => const CheckinPage(),
    ),
    GoRoute(
      path: AppRoute.cart.path,
      name: AppRoute.cart.name,
      builder: (context, state) => const CartPage(),
    ),
    GoRoute(
      path: AppRoute.checkout.path,
      name: AppRoute.checkout.name,
      builder: (context, state) {
        final args = state.extra as CheckoutArguments?;
        return BlocProvider(
          create: (_) => getItInjector<CartBloc>(),
          child: CheckoutPage(arguments: args),
        );
      },
    ),
    GoRoute(
      path: AppRoute.showcase.path,
      name: AppRoute.showcase.name,
      builder: (context, state) => const PromotionsGalleryScreen(),
    ),
    GoRoute(
      path: AppRoute.termsOfService.path,
      name: AppRoute.termsOfService.name,
      builder: (context, state) => const LegalDocumentViewer(
        documentType: LegalDocumentType.termsOfService,
      ),
    ),
    GoRoute(
      path: AppRoute.privacyPolicy.path,
      name: AppRoute.privacyPolicy.name,
      builder: (context, state) => const LegalDocumentViewer(
        documentType: LegalDocumentType.privacyPolicy,
      ),
    ),
  ],
);
