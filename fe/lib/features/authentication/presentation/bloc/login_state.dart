import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.initial() = Initial;
  const factory LoginState.loading() = Loading;
  const factory LoginState.codeSent({required String verificationId, required String phoneNumber}) = CodeSent;
  const factory LoginState.success() = Success;
  const factory LoginState.failure({required String error}) = Failure;
}

