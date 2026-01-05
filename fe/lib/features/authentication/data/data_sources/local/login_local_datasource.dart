import 'package:barz/core/network/dio_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginLocalDataSource {
  final SharedPreferences sharedPreferences;

  LoginLocalDataSource({required this.sharedPreferences});

  Future<void> cacheTokens(String accessToken, String refreshToken) async {
    await sharedPreferences.setString('user_token', accessToken);
    DioNetwork.setTokens(accessToken, refreshToken);
  }

  Future<String?> getCachedUserToken() async {
    return sharedPreferences.getString('user_token');
  }

  Future<void> clearCachedTokens() async {
    await sharedPreferences.remove('user_token');
    await DioNetwork.clearTokens();
  }
}