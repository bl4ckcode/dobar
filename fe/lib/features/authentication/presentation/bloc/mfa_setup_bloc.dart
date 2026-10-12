import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'mfa_setup_event.dart';
import 'mfa_setup_state.dart';

class MfaSetupBloc extends Bloc<MfaSetupEvent, MfaSetupState> {
  final LoginUsecase _loginUsecase;

  MfaSetupBloc(this._loginUsecase) : super(const MfaSetupState.initial()) {
    on<InitiateSetup>(_onInitiateSetup);
    on<VerifyAndActivate>(_onVerifyAndActivate);
  }

  Future<void> _onInitiateSetup(
    InitiateSetup event,
    Emitter<MfaSetupState> emit,
  ) async {
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

  Future<void> _onVerifyAndActivate(
    VerifyAndActivate event,
    Emitter<MfaSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MfaSetupLoaded && currentState is! MfaSetupVerifying) {
      return;
    }

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

    final result = await _loginUsecase.verifyMfa(event.code);
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
