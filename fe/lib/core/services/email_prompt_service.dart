import 'package:shared_preferences/shared_preferences.dart';

class EmailPromptService {
  static const _dismissedAtKey = 'email_prompt_dismissed_at';
  static const _dismissCountKey = 'email_prompt_dismiss_count';
  static const _cooldownDuration = Duration(hours: 24);

  final SharedPreferences _prefs;

  EmailPromptService(this._prefs);

  bool shouldShowPrompt({required bool hasEmail}) {
    if (hasEmail) return false;

    final dismissedAt = _prefs.getInt(_dismissedAtKey);
    if (dismissedAt == null) return true;

    final dismissedTime = DateTime.fromMillisecondsSinceEpoch(dismissedAt);
    final elapsed = DateTime.now().difference(dismissedTime);
    return elapsed > _cooldownDuration;
  }

  Future<void> markDismissed() async {
    await _prefs.setInt(_dismissedAtKey, DateTime.now().millisecondsSinceEpoch);
    final count = _prefs.getInt(_dismissCountKey) ?? 0;
    await _prefs.setInt(_dismissCountKey, count + 1);
  }

  int get dismissCount => _prefs.getInt(_dismissCountKey) ?? 0;

  Future<void> clearDismissed() async {
    await _prefs.remove(_dismissedAtKey);
  }
}
