import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometryService {
  static const _key = 'barz_biometry_status';

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometryService(this._prefs);

  String? get status => _prefs.getString(_key);
  bool get isEnabled => status == 'enabled';
  bool get isDeclined => status == 'declined';

  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!await isAvailable) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> enable() async {
    await _prefs.setString(_key, 'enabled');
  }

  Future<void> decline() async {
    await _prefs.setString(_key, 'declined');
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
