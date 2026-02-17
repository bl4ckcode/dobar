import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/bloc/mfa_setup_cubit.dart';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUsecase extends Mock implements LoginUsecase {}

void main() {
  late MfaSetupCubit mfaSetupCubit;
  late MockLoginUsecase mockLoginUsecase;

  setUp(() {
    mockLoginUsecase = MockLoginUsecase();
    mfaSetupCubit = MfaSetupCubit(mockLoginUsecase);
  });

  tearDown(() {
    mfaSetupCubit.close();
  });

  group('MfaSetupCubit', () {
    const tSecret = 'secret_key';
    const tQrCode = 'qr_code_url';
    final tSetupResponse = {'secret': tSecret, 'qr_code': tQrCode};

    test('initiateSetup emits [Loading, Loaded] when success', () async {
      // Arrange
      when(
        () => mockLoginUsecase.setupMfa(),
      ).thenAnswer((_) async => Right(tSetupResponse));

      // Assert
      final expectedStates = [
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(loading: (_) => true, orElse: () => false),
          'loading',
          true,
        ),
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(
            loaded: (l) => l.secret == tSecret && l.qrCode == tQrCode,
            orElse: () => false,
          ),
          'loaded',
          true,
        ),
      ];
      expectLater(mfaSetupCubit.stream, emitsInOrder(expectedStates));

      // Act
      mfaSetupCubit.initiateSetup();
    });

    test('verifyAndActivate emits [Verifying, Success] when success', () async {
      // Arrange
      const tCode = '123456';

      when(
        () => mockLoginUsecase.setupMfa(),
      ).thenAnswer((_) async => Right(tSetupResponse));
      when(
        () => mockLoginUsecase.verifyMfa(tCode),
      ).thenAnswer((_) async => const Right(null));

      // Act - Set state to Loaded by calling initiateSetup first
      await mfaSetupCubit.initiateSetup();

      // Assert
      final expectedStates = [
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(verifying: (_) => true, orElse: () => false),
          'verifying',
          true,
        ),
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(success: (_) => true, orElse: () => false),
          'success',
          true,
        ),
      ];
      expectLater(mfaSetupCubit.stream, emitsInOrder(expectedStates));

      // Now call verifyAndActivate
      mfaSetupCubit.verifyAndActivate(tCode);
    });

    test('verifyAndActivate emits [Verifying, Failure] when fails', () async {
      // Arrange
      const tCode = '123456';
      const tError = 'Invalid Code';

      when(
        () => mockLoginUsecase.setupMfa(),
      ).thenAnswer((_) async => Right(tSetupResponse));
      when(
        () => mockLoginUsecase.verifyMfa(tCode),
      ).thenAnswer((_) async => Left(ServerFailure(tError, 400)));

      // Act
      await mfaSetupCubit.initiateSetup();

      // Assert
      final expectedStates = [
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(verifying: (_) => true, orElse: () => false),
          'verifying',
          true,
        ),
        isA<MfaSetupState>().having(
          (s) => s.maybeMap(
            errorDuringVerification: (f) => f.error == tError,
            orElse: () => false,
          ),
          'failure',
          true,
        ),
      ];
      expectLater(mfaSetupCubit.stream, emitsInOrder(expectedStates));

      mfaSetupCubit.verifyAndActivate(tCode);
    });
  });
}
