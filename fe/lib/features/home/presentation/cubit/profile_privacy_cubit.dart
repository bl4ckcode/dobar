import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePrivacyState {
  const ProfilePrivacyState({
    this.settings,
    this.loading = true,
    this.saving = false,
    this.failed = false,
    this.saved = false,
  });
  final PrivacySettings? settings;
  final bool loading;
  final bool saving;
  final bool failed;
  final bool saved;
}

/// Location/data-sharing preferences (C04-AC02). A load failure shows retry;
/// it never substitutes defaults that look like saved choices.
class ProfilePrivacyCubit extends Cubit<ProfilePrivacyState> {
  ProfilePrivacyCubit(this._users) : super(const ProfilePrivacyState());
  final UserUsecase _users;

  Future<void> load() async {
    emit(const ProfilePrivacyState());
    final result = await _users.getPrivacySettings();
    if (isClosed) return;
    result.fold(
      (_) => emit(const ProfilePrivacyState(loading: false, failed: true)),
      (s) => emit(ProfilePrivacyState(settings: s, loading: false)),
    );
  }

  void change(PrivacySettings settings) {
    if (!state.saving) {
      emit(ProfilePrivacyState(settings: settings, loading: false));
    }
  }

  Future<void> save() async {
    final settings = state.settings;
    if (settings == null || state.saving) return;
    emit(ProfilePrivacyState(settings: settings, loading: false, saving: true));
    final result = await _users.updatePrivacySettings(settings);
    if (isClosed) return;
    result.fold(
      (_) => emit(
        ProfilePrivacyState(settings: settings, loading: false, failed: true),
      ),
      (saved) => emit(
        ProfilePrivacyState(settings: saved, loading: false, saved: true),
      ),
    );
  }
}
