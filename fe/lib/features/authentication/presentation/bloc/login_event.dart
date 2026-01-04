import 'package:firebase_auth/firebase_auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_event.freezed.dart';

@freezed
sealed class LoginEvent with _$LoginEvent {
  const factory LoginEvent.loginButtonPressed({
    required String phoneNumber,
  }) = LoginButtonPressed;

  const factory LoginEvent.verifyCodeButtonPressed({
    required String verificationId,
    required String smsCode,
  }) = VerifyCodeButtonPressed;

  const factory LoginEvent.googleLoginPressed({
    required String key,
    required String token,
  }) = GoogleLoginPressed;

  const factory LoginEvent.appleLoginPressed({
    required String key,
    required String token,
  }) = AppleLoginPressed;

  const factory LoginEvent.autoVerifyCompleted(
    PhoneAuthCredential credential,
  ) = LoginAutoVerifyCompleted;

  const factory LoginEvent.verificationFailed(
    String error,
  ) = LoginVerificationFailed;

  const factory LoginEvent.codeSent(
    String verificationId,
    String phoneNumber,
  ) = LoginCodeSent;

  const factory LoginEvent.verificationTimeout(
    String verificationId,
  ) = LoginVerificationTimeout;
}
