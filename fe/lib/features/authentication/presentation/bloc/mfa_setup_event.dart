import 'package:freezed_annotation/freezed_annotation.dart';

part 'mfa_setup_event.freezed.dart';

@freezed
sealed class MfaSetupEvent with _$MfaSetupEvent {
  const factory MfaSetupEvent.initiateSetup() = InitiateSetup;
  const factory MfaSetupEvent.verifyAndActivate(String code) =
      VerifyAndActivate;
}
