import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/storage/secure_storage.dart';
import 'package:barz/core/services/token_storage_service.dart';
import 'package:barz/core/services/version_migration_service.dart';
import 'package:barz/core/services/app_initializer.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/services/notifications/notification_navigation_handler.dart';
import 'data/data_sources/app_shared_prefs.dart';

Future<void> initAppInjections() async {
  getItInjector.registerFactory<AppSharedPrefs>(
    () => AppSharedPrefs(getItInjector()),
  );

  getItInjector.registerLazySingleton<SecureStorage>(() => SecureStorage());

  getItInjector.registerLazySingleton<TokenStorageService>(
    () => TokenStorageService(),
  );

  getItInjector.registerLazySingleton<VersionMigrationService>(
    () =>
        VersionMigrationService(secureStorage: getItInjector<SecureStorage>()),
  );

  getItInjector.registerLazySingleton<AppInitializer>(
    () => AppInitializer(
      versionMigrationService: getItInjector<VersionMigrationService>(),
      notificationNavigationHandler:
          getItInjector<NotificationNavigationHandler>(),
      dio: DioNetwork.appAPI,
    ),
  );
}
