import 'package:shared_preferences/shared_preferences.dart';

class AppSharedPrefs {
  final SharedPreferences _preferences;

  AppSharedPrefs(this._preferences);

  /// __________ Dark Theme __________ ///
  bool getIsDarkTheme() {
    return _preferences.getBool("theme") ?? false;
  }

  void setDarkTheme(bool isDark) {
    _preferences.setBool("theme", isDark);
  }
}