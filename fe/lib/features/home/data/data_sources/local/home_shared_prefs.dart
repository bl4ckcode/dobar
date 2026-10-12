import 'package:shared_preferences/shared_preferences.dart';

class HomeSharedPrefs {
  final SharedPreferences _preferences;

  HomeSharedPrefs(this._preferences);

  Future<bool> clearAllLocalData() async {
    return _preferences.clear();
  }
}
