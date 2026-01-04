import 'dart:async';

import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUseCase;
  final FirebaseAuth firebaseAuth;
  final UserRepository? userRepository;

  LoginBloc({
    required this.loginUseCase,
    required this.firebaseAuth,
    this.userRepository,
  }) : super(const LoginState.initial()) {
    on<LoginButtonPressed>(_onLoginButtonPressed);
    on<VerifyCodeButtonPressed>(_onVerifyCodeButtonPressed);
    on<GoogleLoginPressed>(_onGoogleLoginPressed);
    on<AppleLoginPressed>(_onAppleLoginPressed);
    on<LoginAutoVerifyCompleted>(_onLoginAutoVerifyCompleted);
    on<LoginVerificationFailed>(_onLoginVerificationFailed);
    on<LoginCodeSent>(_onLoginCodeSent);
    on<LoginVerificationTimeout>(_onLoginVerificationTimeout);
  }

  /// Check if user profile is complete
  Future<(bool isComplete, String? email, String? name)> _checkProfileComplete() async {
    if (userRepository == null) {
      return (true, null, null); // Assume complete if no repo available
    }
    
    try {
      final result = await userRepository!.getCurrentUser();
      return result.fold(
        (failure) => (false, null, null), // New user, needs registration
        (user) {
          // Profile is complete if user has name, email, and accepted terms
          final isComplete = user.displayName != null && 
                            user.displayName!.isNotEmpty &&
                            user.email != null &&
                            user.email!.isNotEmpty &&
                            user.termsAccepted &&
                            user.privacyAccepted;
          return (isComplete, user.email, user.displayName);
        },
      );
    } catch (_) {
      return (false, null, null);
    }
  }

  Future<void> _onLoginButtonPressed(
      LoginButtonPressed event, Emitter<LoginState> emit) async {
    emit(const LoginState.loading());

    try {
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        verificationCompleted: (credential) {
          add(LoginEvent.autoVerifyCompleted(credential));
        },
        verificationFailed: (e) {
          add(LoginEvent.verificationFailed(
              e.message ?? 'Verification failed'));
        },
        codeSent: (verificationId, _) {
          add(LoginEvent.codeSent(verificationId, event.phoneNumber));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          add(LoginEvent.verificationTimeout(verificationId));
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
      final result = await loginUseCase.verifySmsCode(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );

      await result.fold(
        (failure) async {
          emit(LoginState.failure(error: failure.errorMessage));
        },
        (firebaseUid) async {
          final (isComplete, email, name) = await _checkProfileComplete();
          emit(LoginState.success(
            isProfileComplete: isComplete,
            email: email,
            displayName: name,
          ));
        },
      );
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
      await loginUseCase.loginWithGoogle(params);
      final (isComplete, email, name) = await _checkProfileComplete();
      emit(LoginState.success(
        isProfileComplete: isComplete,
        email: email ?? event.key,
        displayName: name,
      ));
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
      final (isComplete, email, name) = await _checkProfileComplete();
      emit(LoginState.success(
        isProfileComplete: isComplete,
        email: email ?? event.key,
        displayName: name,
      ));
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onLoginAutoVerifyCompleted(
    LoginAutoVerifyCompleted event,
    Emitter<LoginState> emit,
  ) async {
    final userCredential =
        await firebaseAuth.signInWithCredential(event.credential);
    final result = await loginUseCase.complete(userCredential.user);

    await result.fold(
      (failure) async => emit(LoginState.failure(error: failure.errorMessage)),
      (_) async {
        final (isComplete, email, name) = await _checkProfileComplete();
        emit(LoginState.success(
          isProfileComplete: isComplete,
          email: email,
          displayName: name,
        ));
      },
    );
  }

  Future<void> _onLoginVerificationFailed(
    LoginVerificationFailed event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginState.failure(error: event.error));
  }

  Future<void> _onLoginCodeSent(
    LoginCodeSent event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginState.codeSent(
      verificationId: event.verificationId,
      phoneNumber: event.phoneNumber,
    ));
  }

  Future<void> _onLoginVerificationTimeout(
    LoginVerificationTimeout event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginState.failure(
        error: "Timeout for verificationId: ${event.verificationId}"));
  }
}
