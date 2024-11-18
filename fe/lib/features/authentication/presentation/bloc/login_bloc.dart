import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUseCase;

  LoginBloc({required this.loginUseCase}) : super(const LoginState.initial()) {
    on<LoginButtonPressed>(_onLoginButtonPressed);
    on<GoogleLoginPressed>(_onGoogleLoginPressed);
    on<AppleLoginPressed>(_onAppleLoginPressed);
    on<FacebookLoginPressed>(_onFacebookLoginPressed);
  }

  Future<void> _onLoginButtonPressed(
      LoginButtonPressed event,
      Emitter<LoginState> emit,
      ) async {
    emit(const LoginState.loading());
    try {
      final params = LoginParams(
        phoneNumber: event.token,  // Assuming the key here is phoneNumber
      );
      await loginUseCase.call(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onGoogleLoginPressed(
      GoogleLoginPressed event,
      Emitter<LoginState> emit,
      ) async {
    emit(const LoginState.loading());
    try {
      // Use Google token for login or pass to your use case
      final params = LoginParams(
        googleId: event.token,  // Google token used here
      );
      await loginUseCase.call(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onAppleLoginPressed(
      AppleLoginPressed event,
      Emitter<LoginState> emit,
      ) async {
    emit(const LoginState.loading());
    try {
      // Use Apple token for login or pass to your use case
      final params = LoginParams(
        appleId: event.token,  // Apple token used here
      );
      await loginUseCase.call(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onFacebookLoginPressed(
      FacebookLoginPressed event,
      Emitter<LoginState> emit,
      ) async {
    emit(const LoginState.loading());
    try {
      // Use Facebook token for login or pass to your use case
      final params = LoginParams(
        facebookId: event.token,  // Facebook token used here
      );
      await loginUseCase.call(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }
}
