import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometryService {
  static const _key = 'barz_biometry_status';

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Track if the user has authenticated with biometry during this session
  bool _authenticatedThisSession = false;

  BiometryService(this._prefs);

  String? get status => _prefs.getString(_key);
  bool get isEnabled => status == 'enabled';
  bool get isDeclined => status == 'declined';
  bool get authenticatedThisSession => _authenticatedThisSession;

  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!await isAvailable) return false;
    try {
      // API for local_auth 3.0.0+:
      // - AuthenticationOptions is removed
      // - stickyAuth renamed to persistAcrossBackgrounding
      // - useErrorDialogs is removed
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      
      if (authenticated) {
        _authenticatedThisSession = true;
      }
      
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  /// Specialized method for the startup lock screen
  Future<bool> unlock() async {
    final success = await authenticate('Authenticate to unlock Barz');
    if (success) {
      _authenticatedThisSession = true;
    }
    return success;
  }

  Future<void> enable() async {
    await _prefs.setString(_key, 'enabled');
  }

  Future<void> decline() async {
    await _prefs.setString(_key, 'declined');
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    _authenticatedThisSession = false;
  }
}
