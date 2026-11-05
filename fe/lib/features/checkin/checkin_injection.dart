import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/features/checkin/domain/repositories/checkin_repository.dart';
import 'package:barz/features/checkin/data/repositories/checkin_network_repository.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';

Future<void> initCheckinInjection() async {
  getItInjector.registerLazySingleton<CheckinRepository>(() => CheckinNetworkRepository(DioNetwork.appAPI));
  getItInjector.registerLazySingleton<CheckinBloc>(() => CheckinBloc(
    barUsecase: getItInjector(), bars: getItInjector(), repository: getItInjector(),
    location: getItInjector(), session: getItInjector(),
  ));
}
