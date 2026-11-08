import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileSettingsState {
  const ProfileSettingsState({
    this.preferences,
    this.loading = false,
    this.saving = false,
    this.failed = false,
    this.saved = false,
  });
  final NotificationPreferences? preferences;
  final bool loading;
  final bool saving;
  final bool failed;
  final bool saved;
}

class ProfileSettingsCubit extends Cubit<ProfileSettingsState> {
  ProfileSettingsCubit(this._users) : super(const ProfileSettingsState());
  final UserUsecase _users;

  Future<void> load() async {
    emit(const ProfileSettingsState(loading: true));
    final result = await _users.getNotificationPreferences();
    if (isClosed) return;
    result.fold(
      (_) => emit(const ProfileSettingsState(failed: true)),
      (prefs) => emit(ProfileSettingsState(preferences: prefs)),
    );
  }

  void change(NotificationPreferences preferences) {
    if (!state.saving) emit(ProfileSettingsState(preferences: preferences));
  }

  Future<void> save() async {
    final prefs = state.preferences;
    if (prefs == null || state.saving) return;
    emit(ProfileSettingsState(preferences: prefs, saving: true));
    final result = await _users.updateNotificationPreferences(prefs);
    if (isClosed) return;
    result.fold(
      (_) => emit(ProfileSettingsState(preferences: prefs, failed: true)),
      (saved) => emit(ProfileSettingsState(preferences: saved, saved: true)),
    );
  }
}
