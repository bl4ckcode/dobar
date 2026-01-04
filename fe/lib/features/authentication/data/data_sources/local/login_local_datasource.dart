import 'package:barz/core/network/dio_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginLocalDataSource {
  final SharedPreferences sharedPreferences;

  LoginLocalDataSource({required this.sharedPreferences});

  Future<void> cacheUserToken(String token) async {
    await sharedPreferences.setString('user_token', token);
    // Also set the token in DioNetwork for immediate API calls
    DioNetwork.setAuthToken(token);
  }

  Future<String?> getCachedUserToken() async {
    return sharedPreferences.getString('user_token');
  }

  Future<void> clearCachedUserToken() async {
    await sharedPreferences.remove('user_token');
    await DioNetwork.clearAuthToken();
  }
}