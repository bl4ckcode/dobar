import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_event.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUsecase extends Mock implements LoginUsecase {}

void main() {
  late MfaSetupBloc mfaSetupBloc;
  late MockLoginUsecase mockLoginUsecase;

  setUp(() {
    mockLoginUsecase = MockLoginUsecase();
    mfaSetupBloc = MfaSetupBloc(mockLoginUsecase);
  });

  tearDown(() {
    mfaSetupBloc.close();
  });

  group('MfaSetupBloc', () {
    const tSecret = 'secret_key';
    const tQrCode = 'qr_code_url';
    final tSetupResponse = {'secret': tSecret, 'qr_code': tQrCode};

    test('InitiateSetup emits [Loading, Loaded] when success', () async {
      // Arrange
      when(
        () => mockLoginUsecase.setupMfa(),
      ).thenAnswer((_) async => Right(tSetupResponse));

      // Assert
      final expectedStates = [
        const MfaSetupState.loading(),
        const MfaSetupState.loaded(secret: tSecret, qrCode: tQrCode),
      ];
      expectLater(mfaSetupBloc.stream, emitsInOrder(expectedStates));

      // Act
      mfaSetupBloc.add(const MfaSetupEvent.initiateSetup());
    });

    test(
      'VerifyAndActivate emits [Verifying, Success] when success (after Loaded)',
      () async {
        // Arrange
        const tCode = '123456';

        when(
          () => mockLoginUsecase.setupMfa(),
        ).thenAnswer((_) async => Right(tSetupResponse));
        when(
          () => mockLoginUsecase.verifyMfa(tCode),
        ).thenAnswer((_) async => const Right(null));

        // Pre-seed state by running setup first (since verifies depend on secret/qr from state)
        mfaSetupBloc.add(const MfaSetupEvent.initiateSetup());
        await Future.delayed(Duration.zero); // Wait for setup to process

        // Act & Assert
        final expectedStates = [
          const MfaSetupState.verifying(secret: tSecret, qrCode: tQrCode),
          const MfaSetupState.success(),
        ];
        expectLater(mfaSetupBloc.stream, emitsInOrder(expectedStates));

        mfaSetupBloc.add(const MfaSetupEvent.verifyAndActivate(tCode));
      },
    );

    test('VerifyAndActivate emits [Verifying, Failure] when fails', () async {
      // Arrange
      const tCode = '123456';
      const tError = 'Invalid Code';

      when(
        () => mockLoginUsecase.setupMfa(),
      ).thenAnswer((_) async => Right(tSetupResponse));
      when(
        () => mockLoginUsecase.verifyMfa(tCode),
      ).thenAnswer((_) async => Left(ServerFailure(tError, 400)));

      // Pre-seed state
      mfaSetupBloc.add(const MfaSetupEvent.initiateSetup());
      await Future.delayed(Duration.zero);

      // Act & Assert
      final expectedStates = [
        const MfaSetupState.verifying(secret: tSecret, qrCode: tQrCode),
        const MfaSetupState.errorDuringVerification(
          secret: tSecret,
          qrCode: tQrCode,
          error: tError,
        ),
      ];
      expectLater(mfaSetupBloc.stream, emitsInOrder(expectedStates));

      mfaSetupBloc.add(const MfaSetupEvent.verifyAndActivate(tCode));
    });
  });
}
