import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/legal/data/legal_repository.dart';

void initLegalInjection() {
  getItInjector.registerLazySingleton<LegalRepository>(
    () => LegalRepository(dio: DioNetwork.appAPI),
  );
}
