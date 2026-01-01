import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barz/core/storage/secure_storage.dart';
import 'package:barz/core/services/version_migration_service.dart';
import 'package:barz/core/services/app_initializer.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/log/app_logger.dart';
import 'package:barz/core/mocks/mock_bar_repository.dart';
import 'package:barz/core/mocks/mock_promotions_repository.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'package:barz/features/bars/data/repositories/bar_repository_impl.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/promotions/data/datasources/promotions_datasource.dart';
import 'package:barz/features/promotions/data/repositories/promotions_repository_impl.dart';
import 'package:barz/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:barz/features/promotions/domain/usecases/promotions_usecase.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';

final getIt = GetIt.instance;

/// Set to true to use mock data instead of real API
const bool _useMockData = true;

Future<void> initDependencies({bool useMock = _useMockData}) async {
  initRootLogger();
  DioNetwork.initDio();
  
  await _registerSharedPrefs();
  _registerCoreServices();
  _registerStorageServices();
  _registerMigrationServices();
  
  if (useMock) {
    _registerMockRepositories();
  } else {
    _registerApis();
    _registerRepositories();
  }
  
  _registerUseCases();
  _registerBlocs();
}

Future<void> _registerSharedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
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

void _registerMockRepositories() {
  // Use mock data for testing when backend is unavailable
  getIt.registerLazySingleton<AbstractBarRepository>(
    () => MockBarRepository(),
  );
  getIt.registerLazySingleton<PromotionsRepository>(
    () => MockPromotionsRepository(),
  );
}

void _registerApis() {
  getIt.registerLazySingleton<BarNetworkDataSource>(
    () => BarNetworkDataSource(dio: DioNetwork.appAPI),
  );
  getIt.registerLazySingleton<PromotionsDatasource>(
    () => PromotionsNetworkDatasource(dio: DioNetwork.appAPI),
  );
}

void _registerRepositories() {
  getIt.registerLazySingleton<AbstractBarRepository>(
    () => BarRepositoryImpl(networkDataSource: getIt<BarNetworkDataSource>()),
  );
  getIt.registerLazySingleton<PromotionsRepository>(
    () => PromotionsRepositoryImpl(getIt<PromotionsDatasource>()),
  );
}

void _registerUseCases() {
  getIt.registerLazySingleton<BarUsecase>(
    () => BarUsecase(repository: getIt<AbstractBarRepository>()),
  );
  getIt.registerLazySingleton<PromotionsUsecase>(
    () => PromotionsUsecase(getIt<PromotionsRepository>()),
  );
}

void _registerBlocs() {
  getIt.registerFactory<BarBloc>(
    () => BarBloc(barUsecase: getIt<BarUsecase>()),
  );
  getIt.registerFactory<PromotionsBloc>(
    () => PromotionsBloc(getIt<PromotionsUsecase>()),
  );
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
