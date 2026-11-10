import 'package:barz/features/venues/domain/venue_category.dart';
import 'package:barz/features/venues/presentation/pages/category_venues_page.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/features/payments/presentation/pages/payment_methods_page.dart';
import 'package:barz/features/home/presentation/cubit/profile_benefits_cubit.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_benefit_venues_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_benefits_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_settings_page.dart';
import 'package:barz/features/home/presentation/cubit/profile_settings_cubit.dart';
import 'package:barz/features/home/presentation/cubit/profile_account_cubit.dart';
import 'package:barz/features/checkin/presentation/checkin_gate.dart';
import 'dart:async';
import 'package:barz/features/session/presentation/entry_coordinator.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/data/storage/invitation_intent_store.dart';
import 'package:barz/features/session/domain/models/invitation_intent.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/ui/shell/app_shell.dart';
import 'package:barz/ui/business/business_root_shell.dart';
import 'package:barz/ui/business/business_settings_page.dart';
import 'package:barz/ui/business/business_dashboard_page.dart';
import 'package:barz/ui/business/cashier_page.dart';
import 'package:barz/ui/business/menu_management_page.dart';
import 'package:barz/ui/business/staff_management_page.dart';
import 'package:barz/features/advertising/presentation/pages/campaigns_page.dart';
import 'package:barz/features/bars/presentation/pages/create_bar/create_bar_page.dart';
import 'package:barz/features/advertising/presentation/pages/subscription_plans_page.dart';
import 'package:barz/features/bars/presentation/pages/bar_detail_page.dart';
import 'package:barz/features/promotions/presentation/pages/promotion_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/order_tracking_page.dart';
import 'package:barz/features/orders/presentation/pages/order_detail_page.dart';
import 'package:barz/features/orders/presentation/pages/orders_page.dart';
import 'package:barz/features/checkin/presentation/pages/checkin_page.dart';
import 'package:barz/features/cart/presentation/pages/cart_page.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/payments/presentation/pages/checkout_page.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/authentication/presentation/pages/biometric_lock_page.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/features/authentication/presentation/pages/complete_registration_page.dart';
import 'package:barz/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:barz/features/authentication/presentation/pages/mfa_challenge_page.dart';
import 'package:barz/features/authentication/presentation/pages/mfa_setup_page.dart';
import 'package:barz/features/authentication/presentation/pages/recovery/recovery_initiate_page.dart';
import 'package:barz/features/authentication/presentation/pages/recovery/recovery_verify_page.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_reader_page.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/promotions/presentation/screens/promotions_gallery_screen.dart';
import 'package:barz/features/legal/presentation/screens/legal_document_viewer.dart';
import 'package:barz/features/legal/domain/models/legal_document.dart';
import 'package:barz/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_edit_page.dart';
import 'package:barz/features/session/presentation/pages/staff_invitation_page.dart';
import 'package:barz/features/user/presentation/bloc/user_bloc.dart';
import 'package:barz/core/router/route_arguments.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _businessShellNavigatorKey = GlobalKey<NavigatorState>();
String? _capturedInvitationLocation;

const _publicRoutes = {
  '/login',
  '/auth/mfa-challenge',
  '/auth/biometry-unlock',
  // B08: Invitation acceptance shows a generic frame when unauthenticated
  '/staff/invitations/accept',
};

class _SessionRouterRefresh extends ChangeNotifier {
  late final StreamSubscription<SessionState> _subscription;
  _SessionRouterRefresh(SessionBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  refreshListenable: _SessionRouterRefresh(getItInjector<SessionBloc>()),
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoute.home.path,
  redirect: (context, state) async {
    final intent = InvitationIntentStore.instance;
    if (state.uri.path.startsWith('/convite/')) {
      final code = parseInvitationCode('https://dobar.app${state.uri}');
      if (code != null) {
        await intent.save(code);
        return EntryCoordinator.invitationLocation(code);
      }
      return AppRoute.staffInvitationAccept.path;
    }
    if (state.uri.path == AppRoute.staffInvitationAccept.path &&
        state.uri.queryParameters['code'] != null) {
      final code = parseInvitationCode('https://dobar.app${state.uri}');
      if (code != null && _capturedInvitationLocation != state.uri.toString()) {
        _capturedInvitationLocation = state.uri.toString();
        await intent.save(code);
      }
    }
    if (state.uri.path != AppRoute.staffInvitationAccept.path) {
      _capturedInvitationLocation = null;
    }
    final isAuthenticated = await DioNetwork.isAuthenticated();
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(currentPath);

    if (!isAuthenticated) {
      if (isPublicRoute) return null;
      if (intent.code != null) {
        return EntryCoordinator.invitationLocation(intent.code!);
      }
      return AppRoute.login.path;
    }

    // If authenticated, check for biometry lock
    final biometryService = getItInjector<BiometryService>();
    if (biometryService.isEnabled &&
        !biometryService.authenticatedThisSession) {
      if (currentPath != AppRoute.biometryUnlock.path) {
        return AppRoute.biometryUnlock.path;
      }
      return null;
    }

    final sessionBloc = getItInjector<SessionBloc>();
    // Ensure session is initialized for any authenticated route, not just home.
    // Without this, deep links to /bars/:id or /checkin bypass initializeForEntry()
    // and CheckinBloc always sees a null userId → UNAUTHORIZED on confirm.
    if (sessionBloc.state is SessionInitial) {
      await sessionBloc.initializeForEntry();
    }
    final businessEntry =
        currentPath.startsWith('/business') &&
        (sessionBloc.state is! SessionReady ||
            sessionBloc.state.currentSession?.barAccess.isEmpty == true);
    final coldSetupEntry =
        (currentPath == AppRoute.onboarding.path ||
            currentPath == AppRoute.createBar.path) &&
        (sessionBloc.state is SessionInitial ||
            sessionBloc.state is SessionLoggedOut);
    if (currentPath == AppRoute.home.path ||
        currentPath == AppRoute.login.path ||
        currentPath == AppRoute.biometryUnlock.path ||
        businessEntry ||
        coldSetupEntry) {
      final destination = await EntryCoordinator(
        sessionBloc,
      ).resolve(currentPath);
      return destination == currentPath ? null : destination;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/convite/:code',
      builder: (_, _) => const StaffInvitationPage(),
    ),
    GoRoute(
      path: AppRoute.login.path,
      name: AppRoute.login.name,
      builder: (context, state) {
        final args = state.extra;
        final pendingCode = args is LoginRouteArguments
            ? args.pendingInvitationCode
            : args is Map
            ? args['pendingInvitationCode'] as String?
            : null;
        return LoginPage(
          pendingInvitationCode:
              pendingCode ?? InvitationIntentStore.instance.code,
          preferredProvider: args is LoginRouteArguments
              ? args.preferredProvider
              : null,
        );
      },
    ),
    GoRoute(
      path: AppRoute.biometryUnlock.path,
      name: AppRoute.biometryUnlock.name,
      builder: (context, state) => const BiometricLockPage(),
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
      redirect: (context, state) {
        final args = state.extra;
        if (args is CompleteRegistrationArguments && args.returnToCheckout) {
          return null;
        }
        return AppRoute.home.path;
      },
      builder: (context, state) {
        final extra = state.extra as CompleteRegistrationArguments;
        return CompleteRegistrationPage(
          prefilledEmail: extra.prefilledEmail,
          prefilledName: extra.prefilledName,
          prefilledPhone: extra.prefilledPhone,
          initialTermsAccepted: extra.termsAccepted,
          initialPrivacyAccepted: extra.privacyAccepted,
          returnToCheckout: extra.returnToCheckout,
        );
      },
    ),
    GoRoute(
      path: AppRoute.mfaChallenge.path,
      name: AppRoute.mfaChallenge.name,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is MfaChallengeArguments) {
          return MfaChallengePage(
            mfaToken: extra.token,
            pendingInvitationCode: extra.pendingInvitationCode,
          );
        }
        final legacy = extra as Map<String, dynamic>?;
        return MfaChallengePage(
          mfaToken: legacy?['token'] as String? ?? '',
          pendingInvitationCode: legacy?['pendingInvitationCode'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoute.mfaSetup.path,
      name: AppRoute.mfaSetup.name,
      builder: (context, state) => const MfaSetupPage(),
    ),
    GoRoute(
      path: AppRoute.recoveryInitiate.path,
      name: AppRoute.recoveryInitiate.name,
      builder: (context, state) => const RecoveryInitiatePage(),
    ),
    GoRoute(
      path: AppRoute.recoveryVerify.path,
      name: AppRoute.recoveryVerify.name,
      builder: (context, state) => const RecoveryVerifyPage(),
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
          path: AppRoute.businessStaff.path,
          name: AppRoute.businessStaff.name,
          builder: (context, state) => const StaffManagementPage(),
        ),
        GoRoute(
          path: AppRoute.businessSubscriptionPlans.path,
          name: AppRoute.businessSubscriptionPlans.name,
          builder: (context, state) => const SubscriptionPlansPage(),
        ),
        GoRoute(
          path: AppRoute.businessSettings.path,
          name: AppRoute.businessSettings.name,
          builder: (context, state) => const BusinessSettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoute.category.path,
      name: AppRoute.category.name,
      redirect: (context, state) =>
          VenueCategory.fromRouteId(state.pathParameters['categoryId']) == null
          ? AppRoute.home.path
          : null,
      builder: (context, state) => CategoryVenuesPage(
        category: VenueCategory.fromRouteId(
          state.pathParameters['categoryId'],
        )!,
      ),
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
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: getItInjector<SessionBloc>()),
            BlocProvider.value(
              value: getItInjector<CheckinBloc>()
                ..add(const LoadActiveCheckin()),
            ),
            BlocProvider(
              create: (context) =>
                  getItInjector<OrderBloc>()
                    ..add(LoadOrderTimeline(orderId: orderId)),
            ),
          ],
          child: OrderTrackingPage(orderId: orderId),
        );
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
      builder: (context, state) => CreateBarPage(
        fromOnboarding:
            (state.extra as CreateBarArguments?)?.fromOnboarding ?? false,
      ),
    ),
    GoRoute(
      path: AppRoute.checkin.path,
      name: AppRoute.checkin.name,
      builder: (context, state) {
        final args = state.extra;
        return CheckinPage(
          initialBar: args is CheckinArguments
              ? args.initialBar
              : args as BarModel?,
          returnOnCheckin: args is CheckinArguments && args.returnOnCheckin,
        );
      },
    ),
    GoRoute(
      path: AppRoute.cart.path,
      name: AppRoute.cart.name,
      builder: (context, state) {
        final barId = state.extra as int?;
        return BlocProvider.value(
          value: getItInjector<SessionBloc>(),
          child: CartPage(barId: barId),
        );
      },
    ),
    GoRoute(
      path: AppRoute.checkout.path,
      name: AppRoute.checkout.name,
      builder: (context, state) {
        final args = state.extra as CheckoutArguments?;
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: getItInjector<CartBloc>()),
            BlocProvider.value(value: getItInjector<UserBloc>()),
            BlocProvider(
              create: (_) =>
                  getItInjector<PaymentBloc>()..add(const LoadSavedCards()),
            ),
          ],
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
    GoRoute(
      path: AppRoute.notifications.path,
      name: AppRoute.notifications.name,
      builder: (context, state) => BlocProvider(
        create: (_) => getItInjector<NotificationBloc>(),
        child: const NotificationsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoute.profileEdit.path,
      name: AppRoute.profileEdit.name,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            ProfileAccountCubit(getItInjector<UserUsecase>())..load(),
        child: const ProfileEditPage(),
      ),
    ),
    GoRoute(
      path: AppRoute.profileSettings.path,
      name: AppRoute.profileSettings.name,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            ProfileSettingsCubit(getItInjector<UserUsecase>())..load(),
        child: const ProfileSettingsPage(),
      ),
    ),
    GoRoute(
      path: AppRoute.profilePayments.path,
      name: AppRoute.profilePayments.name,
      builder: (context, state) => PaymentMethodsPage.withBloc(),
    ),
    GoRoute(
      path: AppRoute.profileBenefits.path,
      name: AppRoute.profileBenefits.name,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            ProfileBenefitsCubit(getItInjector<UserUsecase>())..load(),
        child: const ProfileBenefitsPage(),
      ),
    ),
    GoRoute(
      path: AppRoute.profileBenefitVenues.path,
      name: AppRoute.profileBenefitVenues.name,
      builder: (context, state) => BlocProvider(
        create: (_) => BenefitVenuesCubit(
          getItInjector<UserUsecase>(),
          state.pathParameters['benefitId']!,
        )..load(),
        child: const ProfileBenefitVenuesPage(),
      ),
    ),
    // B08-FE: Staff invitation acceptance — /staff/invitations/accept?code=<code>
    GoRoute(
      path: AppRoute.staffInvitationAccept.path,
      name: AppRoute.staffInvitationAccept.name,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return BlocProvider.value(
          value: getItInjector<SessionBloc>(),
          child: StaffInvitationPage(
            initialCode: code,
            choose: state.uri.queryParameters['choose'] == 'true',
          ),
        );
      },
    ),
  ],
);
