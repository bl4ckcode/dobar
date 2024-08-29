import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_params.freezed.dart';
part 'login_params.g.dart';

@freezed
class LoginParams with _$LoginParams {
  const factory LoginParams({
    String? phoneNumber,
    String? email,
    String? password,
    String? googleId,
    String? appleId,
  }) = _LoginParams;

  factory LoginParams.fromJson(Map<String, dynamic> json) =>
      _$LoginParamsFromJson(json);
}