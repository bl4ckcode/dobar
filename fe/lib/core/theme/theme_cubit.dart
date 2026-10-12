import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/data/data_sources/app_shared_prefs.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final AppSharedPrefs _prefs;

  ThemeCubit(this._prefs)
    : super(_prefs.getIsDarkTheme() ? ThemeMode.dark : ThemeMode.light);

  void toggleTheme() {
    final isDark = state == ThemeMode.dark;
    _prefs.setDarkTheme(!isDark);
    emit(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void setTheme(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      _prefs.setDarkTheme(true);
      emit(ThemeMode.dark);
    } else if (mode == ThemeMode.light) {
      _prefs.setDarkTheme(false);
      emit(ThemeMode.light);
    }
  }
}
