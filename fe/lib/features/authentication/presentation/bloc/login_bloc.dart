import 'dart:async';

import 'package:barz/core/network/auth_response.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'login_event.dart';
import 'login_state.dart' hide Failure;

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUsecase loginUseCase;
  final FirebaseAuth firebaseAuth;
  final UserRepository? userRepository;

  /// Track current phone number for onboarding country detection
  String? _currentPhoneNumber;

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
    on<MfaChallengeSubmitted>(_onMfaChallengeSubmitted);
  }

  Future<void> _processLoginResult(
    Either<Failure, AuthResponse?> result,
    Emitter<LoginState> emit, {
    String? email,
    String? phoneNumber,
  }) async {
    await result.fold(
      (failure) async {
        emit(LoginState.failure(error: failure.errorMessage));
      },
      (authResponse) async {
        if (authResponse?.mfaRequired == true &&
            authResponse?.mfaToken != null) {
          emit(LoginState.mfaRequired(mfaToken: authResponse!.mfaToken!));
          return;
        }

        final profileResult = await _checkProfileComplete();
        emit(
          LoginState.success(
            isProfileComplete: profileResult.isComplete,
            needsOnboarding: profileResult.needsOnboarding,
            phoneNumber: phoneNumber ?? _currentPhoneNumber,
            email: profileResult.email ?? email,
            displayName: profileResult.name,
          ),
        );
      },
    );
  }

  /// Check if user profile is complete and if onboarding is needed
  Future<({bool isComplete, bool needsOnboarding, String? email, String? name})>
  _checkProfileComplete() async {
    if (userRepository == null) {
      return (
        isComplete: true,
        needsOnboarding: false,
        email: null,
        name: null,
      );
    }

    try {
      final result = await userRepository!.getCurrentUser();
      return result.fold(
        (failure) {
          // 404 = new user needs registration and onboarding
          // 500+ = server error, assume complete to not block user
          if (failure is ServerFailure && failure.statusCode != null) {
            if (failure.statusCode! >= 500) {
              return (
                isComplete: true,
                needsOnboarding: false,
                email: null,
                name: null,
              ); // Don't block on server errors
            }
          }
          // New user - needs both profile completion and onboarding
          return (
            isComplete: false,
            needsOnboarding: true,
            email: null,
            name: null,
          );
        },
        (user) {
          final isComplete =
              user.displayName != null &&
              user.displayName!.isNotEmpty &&
              user.email != null &&
              user.email!.isNotEmpty &&
              user.termsAccepted &&
              user.privacyAccepted;
          // Check if user needs onboarding (no country_code set)
          final needsOnboarding = !user.hasCompletedOnboarding;
          return (
            isComplete: isComplete,
            needsOnboarding: needsOnboarding,
            email: user.email,
            name: user.displayName,
          );
        },
      );
    } catch (_) {
      return (
        isComplete: true,
        needsOnboarding: false,
        email: null,
        name: null,
      ); // Don't block on unexpected errors
    }
  }

  Future<void> _onLoginButtonPressed(
    LoginButtonPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState.loading());

    // Store phone number for country detection during onboarding
    _currentPhoneNumber = event.phoneNumber;

    try {
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        verificationCompleted: (credential) {
          if (!isClosed) add(LoginEvent.autoVerifyCompleted(credential));
        },
        verificationFailed: (e) {
          if (!isClosed) {
            add(
              LoginEvent.verificationFailed(e.message ?? 'Verification failed'),
            );
          }
        },
        codeSent: (verificationId, _) {
          if (!isClosed) {
            add(LoginEvent.codeSent(verificationId, event.phoneNumber));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!isClosed) add(LoginEvent.verificationTimeout(verificationId));
        },
      );
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onVerifyCodeButtonPressed(
    VerifyCodeButtonPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState.loading());

    try {
      final result = await loginUseCase.verifySmsCode(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );

      await _processLoginResult(result, emit, phoneNumber: event.phoneNumber);
    } catch (e) {
      emit(LoginState.failure(error: "Invalid verification code."));
    }
  }

  Future<void> _onGoogleLoginPressed(
    GoogleLoginPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState.loading());

    try {
      final params = LoginParams(
        email: event.key,
        idToken: event.token,
        tokenExpiration: event.tokenExpiration,
      );
      final result = await loginUseCase.loginWithGoogle(params);
      await _processLoginResult(result, emit, email: event.key);
      await _processLoginResult(
        Right(
          result.fold((l) => null, (r) => r),
        ), // Convert output to match helper if needed, but actually usecase returns Either<Failure, AuthResponse?> so just use result directly if type matches
        emit,
        email: event.key,
      );
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
      final params = LoginParams(
        email: event.key,
        idToken: event.token,
        tokenExpiration: event.tokenExpiration,
      );
      final result = await loginUseCase.loginWithApple(params);
      await _processLoginResult(result, emit, email: event.key);
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }

  Future<void> _onLoginAutoVerifyCompleted(
    LoginAutoVerifyCompleted event,
    Emitter<LoginState> emit,
  ) async {
    final userCredential = await firebaseAuth.signInWithCredential(
      event.credential,
    );
    final loginResult = await loginUseCase.complete(userCredential.user);

    await _processLoginResult(
      loginResult,
      emit,
      phoneNumber: _currentPhoneNumber,
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
    emit(
      LoginState.codeSent(
        verificationId: event.verificationId,
        phoneNumber: event.phoneNumber,
      ),
    );
  }

  Future<void> _onLoginVerificationTimeout(
    LoginVerificationTimeout event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      LoginState.failure(
        error: "Timeout for verificationId: ${event.verificationId}",
      ),
    );
  }

  Future<void> _onMfaChallengeSubmitted(
    MfaChallengeSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState.loading());
    try {
      final result = await loginUseCase.mfaChallenge(
        event.mfaToken,
        event.code,
      );
      await _processLoginResult(
        result.map((r) => r), // Upcast AuthResponse to AuthResponse?
        emit,
      );
    } catch (e) {
      emit(LoginState.failure(error: e.toString()));
    }
  }
}
