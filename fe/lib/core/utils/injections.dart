import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/log/app_logger.dart';
import 'package:barz/features/authentication/auth_injection.dart';
import 'package:barz/features/home/home_injection.dart';
import 'package:barz/features/partners/partners_injection.dart';
import 'package:barz/shared/app_injections.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getItInjector = GetIt.instance;

Future<void> initInjections() async {
  await initSharedPrefsInjections();
  await initAppInjections();
  await initDioInjections();
  await initLoginInjections();
  await initHomeInjections();
  await initPartnersInjection();
}

initSharedPrefsInjections() async {
  getItInjector.registerSingletonAsync<SharedPreferences>(() async {
    return await SharedPreferences.getInstance();
  });
  await getItInjector.isReady<SharedPreferences>();
}

Future<void> initDioInjections() async {
  initRootLogger();
  DioNetwork.initDio();
}
