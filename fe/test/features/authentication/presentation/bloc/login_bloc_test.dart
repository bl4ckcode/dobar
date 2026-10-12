import 'package:barz/core/network/auth_response.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart'
    as ls;
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUsecase extends Mock implements LoginUsecase {}

class MockUserRepository extends Mock implements UserRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late LoginBloc loginBloc;
  late MockLoginUsecase mockLoginUsecase;
  late MockUserRepository mockUserRepository;
  late MockFirebaseAuth mockFirebaseAuth;

  setUp(() {
    mockLoginUsecase = MockLoginUsecase();
    mockUserRepository = MockUserRepository();
    mockFirebaseAuth = MockFirebaseAuth();
    loginBloc = LoginBloc(
      loginUseCase: mockLoginUsecase,
      userRepository: mockUserRepository,
      firebaseAuth: mockFirebaseAuth,
    );
  });

  tearDown(() {
    loginBloc.close();
  });

  group('MfaChallengeSubmitted', () {
    const tMfaToken = 'mfa_token_123';
    const tCode = '123456';
    final tAuthResponse = AuthResponse(
      accessToken: 'access_token',
      refreshToken: 'refresh_token',
      mfaRequired: false,
    );

    test('emits [Loading, Success] when mfaChallenge succeeds', () async {
      // Arrange
      when(
        () => mockLoginUsecase.mfaChallenge(tMfaToken, tCode),
      ).thenAnswer((_) async => Right(tAuthResponse));

      final tUserModel = UserModel(id: 1, phoneNumber: '1234567890');
      when(() => mockUserRepository.getCurrentUser()).thenAnswer(
        (_) async => Right(tUserModel),
      ); // Profile complete or mocked
      // Actually _checkProfileComplete handles null userRepository gracefully?
      // Or if it returns Right(null), it implies incomplete.
      // Let's check _checkProfileComplete logic in LoginBloc.
      // It calls userRepository?.getUserProfile().
      // If result is Right(null), it assumes incomplete.

      // Act
      loginBloc.add(LoginEvent.mfaChallengeSubmitted(tMfaToken, tCode));

      // Assert
      await expectLater(
        loginBloc.stream,
        emitsInOrder([isA<ls.Loading>(), isA<ls.Success>()]),
      );
    });

    test('emits [Loading, Failure] when mfaChallenge fails', () async {
      // Arrange
      const tError = 'Invalid Code';
      when(
        () => mockLoginUsecase.mfaChallenge(tMfaToken, tCode),
      ).thenAnswer((_) async => Left(ServerFailure(tError, 400)));

      // Act
      loginBloc.add(LoginEvent.mfaChallengeSubmitted(tMfaToken, tCode));

      // Assert
      await expectLater(
        loginBloc.stream,
        emitsInOrder([
          isA<ls.Loading>(),
          isA<ls.Failure>().having((s) => s.error, 'error', tError),
        ]),
      );
    });
  });
}
