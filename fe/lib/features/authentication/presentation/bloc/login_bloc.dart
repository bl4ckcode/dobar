import 'dart:async';

import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUseCase;
  final FirebaseAuth firebaseAuth;

  LoginBloc({
    required this.loginUseCase,
    required this.firebaseAuth,
  }) : super(const LoginState.initial()) {
    on<LoginButtonPressed>(_onLoginButtonPressed);
    on<VerifyCodeButtonPressed>(_onVerifyCodeButtonPressed);
    on<GoogleLoginPressed>(_onGoogleLoginPressed);
    on<AppleLoginPressed>(_onAppleLoginPressed);
    on<FacebookLoginPressed>(_onFacebookLoginPressed);
  }

  Future<void> _onLoginButtonPressed(
      LoginButtonPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    emit(LoginState.codeSent(verificationId: "", phoneNumber: event.phoneNumber));

    // try {
    //   final params = LoginParams(
    //     phoneNumber: event.phoneNumber,
    //   );
    //
    //   final result = await loginUseCase.loginWithPhone(params);
    //
    //   result.fold(
    //     (failure) {
    //       emit(LoginState.failure(error: failure.errorMessage));
    //     },
    //     (verificationId) {
    //       emit(LoginState.codeSent(verificationId: verificationId ?? "", phoneNumber: event.phoneNumber));
    //     },
    //   );
    // } catch (e) {
    //   emit(LoginState.failure(error: e.toString()));
    // }
  }

  Future<void> _onVerifyCodeButtonPressed(
      VerifyCodeButtonPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    emit(const LoginState.success());
    // try {
    //   final result = await loginUseCase.verifySmsCode(
    //     verificationId: event.verificationId,
    //     smsCode: event.smsCode,
    //   );
    //
    //   result.fold(
    //     (failure) {
    //       emit(LoginState.failure(error: failure.errorMessage));
    //     },
    //     (firebaseUid) {
    //       emit(const LoginState.success());
    //     },
    //   );
    // } catch (e) {
    //   emit(LoginState.failure(error: "Invalid verification code."));
    // }
  }

  Future<void> _onGoogleLoginPressed(
      GoogleLoginPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      final params = LoginParams(
        email: event.key,
        googleId: event.token,
      );
      await loginUseCase.loginWithGoogle(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onAppleLoginPressed(
      AppleLoginPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      final params = LoginParams(
        email: event.key,
        appleId: event.token,
      );
      await loginUseCase.loginWithApple(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onFacebookLoginPressed(
      FacebookLoginPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      final params = LoginParams(
        email: event.key,
        facebookId: event.token,
      );
      await loginUseCase.loginWithFacebook(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }
}
