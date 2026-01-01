import 'package:get_it/get_it.dart';
import 'package:barz/core/storage/secure_storage.dart';
import 'package:barz/core/services/version_migration_service.dart';
import 'package:barz/core/services/app_initializer.dart';

final getIt = GetIt.instance;

/// Initialize all dependencies for the app
/// 
/// This follows Clean Architecture principles:
/// 1. Register services first (storage, network, etc.)
/// 2. Register repositories (depend on services)
/// 3. Register use cases (depend on repositories)
/// 4. Register blocs/controllers (depend on use cases)
void initDependencies({bool useMock = false}) {
  // --- CORE SERVICES ---
  _registerCoreServices();
  
  // --- STORAGE ---
  _registerStorageServices();
  
  // --- VERSION MIGRATION ---
  _registerMigrationServices();
  
  // --- APIs ---
  if (useMock) {
    _registerMockApis();
  } else {
    _registerApis();
  }
  
  // --- REPOSITORIES ---
  _registerRepositories();
  
  // --- USE CASES ---
  _registerUseCases();
  
  // --- BLOCS ---
  _registerBlocs();
}

void _registerCoreServices() {
  // Add network client, API configuration, etc.
  // getIt.registerLazySingleton<ApiClient>(() => ApiClient(ApiPaths.baseUrl));
}

void _registerStorageServices() {
  // Secure storage for tokens and sensitive data
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage());
}

void _registerMigrationServices() {
  // Version migration service to prevent logout on app updates
  getIt.registerLazySingleton<VersionMigrationService>(
    () => VersionMigrationService(
      secureStorage: getIt<SecureStorage>(),
    ),
  );
  
  // App initializer for startup tasks
  getIt.registerLazySingleton<AppInitializer>(
    () => AppInitializer(
      versionMigrationService: getIt<VersionMigrationService>(),
    ),
  );
}

void _registerMockApis() {
  // Register mock implementations for testing
  // getIt.registerLazySingleton<AbstractAuthApi>(() => AuthApiMock());
}

void _registerApis() {
  // Register real API implementations
  // getIt.registerLazySingleton<AbstractAuthApi>(() => AuthApi(getIt<ApiClient>()));
}

void _registerRepositories() {
  // Register repositories
  // getIt.registerLazySingleton<AuthRepository>(
  //   () => AuthRepositoryImpl(getIt<AbstractAuthApi>()),
  // );
}

void _registerUseCases() {
  // Register use cases
  // getIt.registerLazySingleton<LoginUseCase>(
  //   () => LoginUseCase(getIt<AuthRepository>()),
  // );
}

void _registerBlocs() {
  // Register blocs as factories (new instance each time)
  // getIt.registerFactory(
  //   () => LoginBloc(loginUseCase: getIt<LoginUseCase>()),
  // );
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
