import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileAccountState {
  const ProfileAccountState({
    this.user,
    this.loading = false,
    this.saving = false,
    this.deleted = false,
    this.error,
    this.saved = false,
  });
  final UserModel? user;
  final bool loading;
  final bool saving;
  final bool deleted;
  final String? error;
  final bool saved;
}

class ProfileAccountCubit extends Cubit<ProfileAccountState> {
  ProfileAccountCubit(this._users) : super(const ProfileAccountState());
  final UserUsecase _users;

  Future<void> load() async {
    if (state.loading || state.saving) return;
    emit(ProfileAccountState(user: state.user, loading: true));
    final result = await _users.getCurrentUser();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ProfileAccountState(user: state.user, error: failure.errorMessage),
      ),
      (user) => emit(ProfileAccountState(user: user)),
    );
  }

  Future<void> save(String name) async {
    if (state.saving || state.loading) return;
    emit(ProfileAccountState(user: state.user, saving: true));
    final result = await _users.updateProfile(displayName: name.trim());
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ProfileAccountState(user: state.user, error: failure.errorMessage),
      ),
      (user) => emit(ProfileAccountState(user: user, saved: true)),
    );
  }

  Future<void> delete() async {
    if (state.saving || state.loading) return;
    emit(ProfileAccountState(user: state.user, saving: true));
    final result = await _users.deleteAccount();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ProfileAccountState(user: state.user, error: failure.errorMessage),
      ),
      (deleted) =>
          emit(ProfileAccountState(user: state.user, deleted: deleted)),
    );
  }
}
