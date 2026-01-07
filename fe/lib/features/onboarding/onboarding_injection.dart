import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/onboarding/data/datasources/onboarding_datasource.dart';
import 'package:barz/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:barz/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_bloc.dart';

void initOnboardingInjection() {
  getItInjector.registerLazySingleton<OnboardingDatasource>(
    () => OnboardingNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(getItInjector<OnboardingDatasource>()),
  );

  getItInjector.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(repository: getItInjector<OnboardingRepository>()),
  );
}
