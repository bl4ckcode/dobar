import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (saved != null) {
      return Locale(saved);
    }
    // Fall back to device locale (will be overridden by device default)
    return const Locale('en');
  }

  /// Sets the app locale and persists the choice.
  void setLocale(Locale locale) {
    _prefs.setString(_localeKey, locale.languageCode);
    emit(locale);
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