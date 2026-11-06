import 'package:flutter/widgets.dart';

class LocaleNotifier extends ValueNotifier<Locale> with WidgetsBindingObserver {
  LocaleNotifier() : super(resolve(WidgetsBinding.instance.platformDispatcher.locale)) {
    WidgetsBinding.instance.addObserver(this);
  }

  static Locale resolve(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    return Locale(const {'pt', 'es', 'en'}.contains(language) ? language : 'en');
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    value = resolve(locales != null && locales.isNotEmpty
        ? locales.first
        : const Locale('en'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
