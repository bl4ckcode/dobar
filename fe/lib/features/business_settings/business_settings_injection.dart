import 'package:barz/core/utils/injections.dart';
import 'data/repositories/business_settings_repository.dart';
import 'domain/repositories/abstract_business_settings_repository.dart';
import 'domain/usecases/business_settings_usecase.dart';
import 'presentation/bloc/business_settings_bloc.dart';

void initBusinessSettings() {
  getItInjector.registerLazySingleton<BusinessSettingsRepositoryInterface>(
    () => BusinessSettingsRepository(),
  );

  getItInjector.registerLazySingleton<BusinessSettingsUsecase>(
    () => BusinessSettingsUsecase(
      getItInjector<BusinessSettingsRepositoryInterface>(),
    ),
  );

  getItInjector.registerFactory<BusinessSettingsBloc>(
    () => BusinessSettingsBloc(
      getItInjector<BusinessSettingsUsecase>(),
    ),
  );
}