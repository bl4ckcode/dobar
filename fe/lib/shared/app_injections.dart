import 'package:barz/core/utils/injections.dart';

import 'data/data_sources/app_shared_prefs.dart';

initAppInjections() {
  getItInjector
      .registerFactory<AppSharedPrefs>(() => AppSharedPrefs(getItInjector()));
}
