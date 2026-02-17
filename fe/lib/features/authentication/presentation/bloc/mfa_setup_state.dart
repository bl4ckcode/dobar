part of 'mfa_setup_cubit.dart';

@freezed
class MfaSetupState with _$MfaSetupState {
  const factory MfaSetupState.initial() = MfaSetupInitial;
  const factory MfaSetupState.loading() = MfaSetupLoading;
  const factory MfaSetupState.loaded({
    required String secret,
    required String qrCode,
  }) = MfaSetupLoaded;
  const factory MfaSetupState.verifying({
    required String secret,
    required String qrCode,
  }) = MfaSetupVerifying;
  const factory MfaSetupState.errorDuringVerification({
    required String secret,
    required String qrCode,
    required String error,
  }) = MfaSetupErrorDuringVerification;
  const factory MfaSetupState.failure(String error) = MfaSetupFailure;
  const factory MfaSetupState.success() = MfaSetupSuccess;
}
