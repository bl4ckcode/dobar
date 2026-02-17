import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mfa_setup_state.dart';
part 'mfa_setup_cubit.freezed.dart';

class MfaSetupCubit extends Cubit<MfaSetupState> {
  final LoginUsecase _loginUsecase;

  MfaSetupCubit(this._loginUsecase) : super(const MfaSetupState.initial());

  Future<void> initiateSetup() async {
    emit(const MfaSetupState.loading());
    final result = await _loginUsecase.setupMfa();
    result.fold(
      (failure) => emit(MfaSetupState.failure(failure.errorMessage)),
      (data) => emit(
        MfaSetupState.loaded(
          secret: data['secret'] ?? '',
          qrCode: data['qr_code'] ?? '',
        ),
      ),
    );
  }

  Future<void> verifyAndActivate(String code) async {
    final currentState = state;
    if (currentState is! MfaSetupLoaded && currentState is! MfaSetupVerifying) {
      return; // simple guard
    }

    // Preserve current data if possible, or just go to Verifying
    String secret = '';
    String qrCode = '';
    if (currentState is MfaSetupLoaded) {
      secret = currentState.secret;
      qrCode = currentState.qrCode;
    } else if (currentState is MfaSetupVerifying) {
      secret = currentState.secret;
      qrCode = currentState.qrCode;
    }

    emit(MfaSetupState.verifying(secret: secret, qrCode: qrCode));

    final result = await _loginUsecase.verifyMfa(code);
    result.fold(
      (failure) => emit(
        MfaSetupState.errorDuringVerification(
          secret: secret,
          qrCode: qrCode,
          error: failure.errorMessage,
        ),
      ),
      (_) => emit(const MfaSetupState.success()),
    );
  }
}
