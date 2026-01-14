import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/router/app_router.dart';
import 'package:barz/core/services/email_prompt_service.dart';
import 'package:barz/core/services/image_refresh_service.dart';
import 'package:barz/core/services/notifications/notification_service.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:barz/core/services/offline/offline.dart';
import 'package:barz/core/utils/log/app_logger.dart';
import 'package:barz/features/advertising/advertising_injection.dart';
import 'package:barz/features/authentication/auth_injection.dart';
import 'package:barz/features/bars/bars_injection.dart';
import 'package:barz/features/cart/cart_injection.dart';
import 'package:barz/features/checkin/checkin_injection.dart';
import 'package:barz/features/home/home_injection.dart';
import 'package:barz/features/location/location_injection.dart';
import 'package:barz/features/menu_reader/menu_reader_injection.dart';
import 'package:barz/features/onboarding/onboarding_injection.dart';
import 'package:barz/features/orders/orders_injection.dart';
import 'package:barz/features/partners/partners_injection.dart';
import 'package:barz/features/payments/payments_injection.dart';
import 'package:barz/features/promotions/promotions_injection.dart';
import 'package:barz/features/session/session_injection.dart';
import 'package:barz/features/trending/trending_injection.dart';
import 'package:barz/features/user/user_injection.dart';
import 'package:barz/shared/app_injections.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getItInjector = GetIt.instance;

Future<void> initInjections() async {
  await initSharedPrefsInjections();
  await initOfflineServicesInjections();
  await initAppInjections();
  await initDioInjections();
  await initNotificationInjections();
  await initLoginInjections();
  await initHomeInjections();
  await initPartnersInjection();
  await initBarsInjection();
  await initCartInjection();
  await initOrdersInjection();
  await initCheckinInjection();
  await initMenuReaderInjection();
  initUserInjection();
  initPaymentsInjection();
  initPromotionsInjection();
  initLocationInjection();
  initOnboardingInjection();
  initAdvertisingInjection();
  registerTrendingFeature(getItInjector);
  await initSessionInjection();
}

Future<void> initSharedPrefsInjections() async {
  getItInjector.registerSingletonAsync<SharedPreferences>(() async {
    return await SharedPreferences.getInstance();
  });
  await getItInjector.isReady<SharedPreferences>();

  getItInjector.registerLazySingleton<EmailPromptService>(
    () => EmailPromptService(getItInjector<SharedPreferences>()),
  );
}

Future<void> initOfflineServicesInjections() async {
  final hiveStorage = HiveStorageService();
  await hiveStorage.initialize();
  getItInjector.registerSingleton<HiveStorageService>(hiveStorage);

  final connectivity = ConnectivityService();
  await connectivity.initialize();
  getItInjector.registerSingleton<ConnectivityService>(connectivity);

  final syncService = SyncService();
  await syncService.initialize();
  getItInjector.registerSingleton<SyncService>(syncService);

  final backgroundWorker = BackgroundWorker();
  await backgroundWorker.initialize();
  await backgroundWorker.registerPeriodicSync();
  await backgroundWorker.scheduleCleanup();
  getItInjector.registerSingleton<BackgroundWorker>(backgroundWorker);
}

Future<void> initDioInjections() async {
  initRootLogger();
  DioNetwork.initDio(
    tokenStorage: getItInjector<TokenStorageService>(),
    onAuthExpired: _handleAuthExpired,
  );
  
  // Load any existing tokens from storage
  await DioNetwork.loadTokensFromStorage();
  
  // Register ImageRefreshService
  getItInjector.registerLazySingleton<ImageRefreshService>(
    () => ImageRefreshService(DioNetwork.appAPI),
  );
}

/// Handle auth expiration by navigating to login
void _handleAuthExpired() {
  // Use the global navigator key to navigate to login
  // This runs after the widget tree is built
  Future.microtask(() {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      appRouter.go('/login');
    }
  });
}

Future<void> initNotificationInjections() async {
  // Register NotificationService singleton
  final notificationService = NotificationService();
  getItInjector.registerSingleton<NotificationService>(notificationService);
  
  // Initialize notifications in background - don't block app startup
  // Permission will be requested lazily, and if denied, app still works
  notificationService.initializeInBackground();
}

