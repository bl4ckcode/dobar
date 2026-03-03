import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_params.freezed.dart';
part 'login_params.g.dart';

@freezed
abstract class LoginParams with _$LoginParams {
  const factory LoginParams({
    String? phoneNumber,
    String? email,
    String? idToken,
    String? firebaseUid,
    int? tokenExpiration,
  }) = _LoginParams;

  factory LoginParams.fromJson(Map<String, dynamic> json) =>
      _$LoginParamsFromJson(json);
}
