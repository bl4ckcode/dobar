import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/network/api_config.dart';

class LoginLocalDataSource {
  final SharedPreferences sharedPreferences;

  LoginLocalDataSource({required this.sharedPreferences});

  Future<void> cacheUserToken(String token) async {
    await sharedPreferences.setString('user_token', token);
  }

  Future<String?> getCachedUserToken() async {
    return sharedPreferences.getString('user_token');
  }

  Future<void> clearCachedUserToken() async {
    await sharedPreferences.remove('user_token');
    setAuthToken("");
  }
}