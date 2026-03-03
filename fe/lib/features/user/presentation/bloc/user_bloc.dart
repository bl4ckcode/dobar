import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/features/user/presentation/bloc/user_event.dart';
import 'package:barz/features/user/presentation/bloc/user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserUsecase _usecase;

  UserBloc(this._usecase) : super(const UserState()) {
    on<LoadCurrentUser>(_onLoadCurrentUser);
    on<UpdateProfile>(_onUpdateProfile);
    on<UpdatePreferences>(_onUpdatePreferences);
    on<AddDocument>(_onAddDocument);
    on<RemoveDocument>(_onRemoveDocument);
    on<AcceptTerms>(_onAcceptTerms);
    on<AcceptPrivacy>(_onAcceptPrivacy);
    on<DeleteAccount>(_onDeleteAccount);
    on<LoadWalletBalance>(_onLoadWalletBalance);
    on<LoadCashbackHistory>(_onLoadCashbackHistory);
    on<ClearUserError>(_onClearError);
  }

  Future<void> _onLoadCurrentUser(
    LoadCurrentUser event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getCurrentUser();
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isLoading: false, user: user)),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.updateProfile(
      displayName: event.displayName,
      email: event.email,
      phoneNumber: event.phoneNumber,
      profilePictureUrl: event.profilePictureUrl,
    );
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onUpdatePreferences(
    UpdatePreferences event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.updatePreferences(event.preferences);
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onAddDocument(
    AddDocument event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.addDocument(event.document);
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onRemoveDocument(
    RemoveDocument event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.removeDocument(event.documentId);
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onAcceptTerms(
    AcceptTerms event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.acceptTerms();
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onAcceptPrivacy(
    AcceptPrivacy event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.acceptPrivacy();
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (user) => emit(state.copyWith(isUpdating: false, user: user)),
    );
  }

  Future<void> _onDeleteAccount(
    DeleteAccount event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(isUpdating: true, error: null));
    final result = await _usecase.deleteAccount();
    result.fold(
      (failure) =>
          emit(state.copyWith(isUpdating: false, error: failure.errorMessage)),
      (_) => emit(const UserState()),
    );
  }

  Future<void> _onLoadWalletBalance(
    LoadWalletBalance event,
    Emitter<UserState> emit,
  ) async {
    final result = await _usecase.getWalletBalance();
    result.fold(
      (failure) => emit(state.copyWith(error: failure.errorMessage)),
      (balance) => emit(state.copyWith(walletBalance: balance)),
    );
  }

  Future<void> _onLoadCashbackHistory(
    LoadCashbackHistory event,
    Emitter<UserState> emit,
  ) async {
    final result = await _usecase.getCashbackHistory();
    result.fold(
      (failure) => emit(state.copyWith(error: failure.errorMessage)),
      (history) => emit(state.copyWith(cashbackHistory: history)),
    );
  }

  void _onClearError(ClearUserError event, Emitter<UserState> emit) {
    emit(state.copyWith(error: null));
  }
}
