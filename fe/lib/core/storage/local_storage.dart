import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
	static const _cartKey = 'cart_state';

	Future<void> saveCart(String cartJson) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString(_cartKey, cartJson);
	}

	Future<String?> getCart() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getString(_cartKey);
	}

	Future<void> deleteCart() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.remove(_cartKey);
	}
}
