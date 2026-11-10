import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_notifier.dart';

/// Manages app locale/language selection.
///
/// Persists the selected locale to SharedPreferences so the choice
/// survives app restarts. Falls back to the device locale on first launch.
class LocaleCubit extends Cubit<Locale> {
  final SharedPreferences _prefs;

  static const _localeKey = 'app_locale';

  LocaleCubit(this._prefs) : super(_loadSavedLocale(_prefs));

  static Locale _loadSavedLocale(SharedPreferences prefs) {
    final saved = prefs.getString(_localeKey);
    if (const {'pt', 'es', 'en'}.contains(saved)) {
      return Locale(saved!);
    }
    return LocaleNotifier.resolve(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  void updateDeviceLocale(Locale locale) {
    if (!const {'pt', 'es', 'en'}.contains(_prefs.getString(_localeKey))) {
      emit(LocaleNotifier.resolve(locale));
    }
  }

  /// Sets the app locale and persists the choice.
  void setLocale(Locale locale) {
    final supported = LocaleNotifier.resolve(locale);
    _prefs.setString(_localeKey, supported.languageCode);
    emit(supported);
  }

  /// Convenience method to set locale by language code string.
  void setLanguageCode(String languageCode) {
    setLocale(Locale(languageCode));
  }

  /// Returns true if the given language code matches the current locale.
  bool isSelected(String languageCode) {
    return state.languageCode == languageCode;
  }
}
