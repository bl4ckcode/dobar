import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/payments/data/data_sources/payment_network_datasource.dart';
import 'package:barz/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:barz/features/payments/domain/repositories/abstract_payment_repository.dart';
import 'package:barz/features/payments/domain/usecases/payment_usecase.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';

void initPaymentsInjection() {
  getItInjector.registerLazySingleton<PaymentDatasource>(
    () => PaymentNetworkDatasource(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(getItInjector<PaymentDatasource>()),
  );

  getItInjector.registerLazySingleton<PaymentUsecase>(
    () => PaymentUsecase(getItInjector<PaymentRepository>()),
  );

  getItInjector.registerFactory<PaymentBloc>(
    () => PaymentBloc(getItInjector<PaymentUsecase>()),
  );
}
