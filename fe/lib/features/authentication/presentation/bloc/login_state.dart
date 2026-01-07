import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.initial() = Initial;
  const factory LoginState.loading() = Loading;
  const factory LoginState.codeSent({required String verificationId, required String phoneNumber}) = CodeSent;
  const factory LoginState.success({
    /// Whether user profile is complete (has name, email, accepted terms)
    @Default(false) bool isProfileComplete,
    /// Whether user needs to complete onboarding (select role + country)
    @Default(false) bool needsOnboarding,
    /// Phone number for country auto-detection in onboarding
    String? phoneNumber,
    /// Pre-filled data from social auth
    String? email,
    String? displayName,
  }) = Success;
  const factory LoginState.failure({required String error}) = Failure;
}

