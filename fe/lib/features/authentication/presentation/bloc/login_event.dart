import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_event.freezed.dart';

@freezed
class LoginEvent with _$LoginEvent {
  const factory LoginEvent.loginButtonPressed({
    required String phoneNumber,
  }) = LoginButtonPressed;

  const factory LoginEvent.googleLoginPressed({
    required String key,
    required String token,
  }) = GoogleLoginPressed;

  const factory LoginEvent.appleLoginPressed({
    required String key,
    required String token,
  }) = AppleLoginPressed;

  const factory LoginEvent.facebookLoginPressed({
    required String key,
    required String token,
  }) = FacebookLoginPressed;
}
