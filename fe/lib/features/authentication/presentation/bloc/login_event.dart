import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_event.freezed.dart';

@freezed
class LoginEvent with _$LoginEvent {
  const factory LoginEvent.loginButtonPressed({
    String? phoneNumber,
    String? email,
    String? password,
    String? googleId,
    String? appleId,
  }) = LoginButtonPressed;
}
