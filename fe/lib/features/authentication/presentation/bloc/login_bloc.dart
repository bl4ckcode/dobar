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

    try {
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Automatically sign in the user if verification completes automatically.
          await firebaseAuth.signInWithCredential(credential);
          emit(const LoginState.success());
        },
        verificationFailed: (FirebaseAuthException e) {
          emit(LoginState.failure(error: e.message ?? "Verification failed."));
        },
        codeSent: (String verificationId, int? resendToken) {
          emit(LoginState.codeSent(verificationId: verificationId));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Called when auto-retrieval times out.
        },
      );
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onVerifyCodeButtonPressed(
      VerifyCodeButtonPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );

      await firebaseAuth.signInWithCredential(credential);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: "Invalid verification code."));
    }
  }

  Future<void> _onGoogleLoginPressed(
      GoogleLoginPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      final params = LoginParams(
        email: event.key,
        googleId: event.token,
      );
      await loginUseCase.call(params);
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
      await loginUseCase.call(params);
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
      await loginUseCase.call(params);
      emit(const LoginState.success());
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }
}
