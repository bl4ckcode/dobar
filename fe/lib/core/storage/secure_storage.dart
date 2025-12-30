import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
	static const _jwtKey = 'jwt_token';
	static const _userKey = 'user_profile';
	final FlutterSecureStorage _storage = const FlutterSecureStorage();

	Future<void> saveJwt(String token) async {
		await _storage.write(key: _jwtKey, value: token);
	}

	Future<String?> getJwt() async {
		return await _storage.read(key: _jwtKey);
	}

	Future<void> deleteJwt() async {
		await _storage.delete(key: _jwtKey);
	}

	Future<void> saveUserProfile(String userJson) async {
		await _storage.write(key: _userKey, value: userJson);
	}

	Future<String?> getUserProfile() async {
		return await _storage.read(key: _userKey);
	}

	Future<void> deleteUserProfile() async {
		await _storage.delete(key: _userKey);
	}
}
