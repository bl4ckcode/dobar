import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/cubit/invitation_cubit.dart';
import 'package:barz/features/session/presentation/cubit/invitation_state.dart';

class _MockSessionUsecase extends Mock implements SessionUsecase {}
class _MockSessionBloc extends Mock implements SessionBloc {
  @override
  SessionState get state => const SessionState.initial();
}

InvitationPreview _fakePreview() => InvitationPreview(
  venueName: 'Bar Teste',
  role: 'cashier',
  maskedRecipient: 'ca***@test.com',
  expiresAt: DateTime.now().add(const Duration(days: 7)),
  permissions: const ['order:view'],
);

BarAccess _fakeAccess() => const BarAccess(
  barId: 42, barName: 'Bar Teste',
  role: BarRole.cashier, permissions: {},
);

void main() {
  late _MockSessionUsecase usecase;
  late _MockSessionBloc bloc;

  setUp(() {
    usecase = _MockSessionUsecase();
    bloc = _MockSessionBloc();
    registerFallbackValue('');
  });

  InvitationCubit make({String? code}) => InvitationCubit(
    sessionUsecase: usecase, sessionBloc: bloc, initialCode: code,
    isAuthenticated: () async => true);

  group('code parsing', () {
    test('accepts bare DBR code and calls previewInvitation', () async {
      when(() => usecase.previewInvitation(any()))
          .thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('normalizes DBR without hyphens', () async {
      when(() => usecase.previewInvitation(any()))
          .thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('DBR7K4M29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('extracts code from dobar.app link', () async {
      when(() => usecase.previewInvitation(any()))
          .thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('https://dobar.app/convite/DBR-7K4M-29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('emits InvitationLoadError for empty input', () async {
      final c = make();
      await c.submitCode('');
      expect(c.state, isA<InvitationLoadError>());
    });

    test('emits InvitationLoadError for malformed code', () async {
      final c = make();
      await c.submitCode('not-a-code');
      expect(c.state, isA<InvitationLoadError>());
    });

    test('rejects non-dobar URL', () async {
      final c = make();
      await c.submitCode('https://evil.com/convite/DBR-7K4M-29QX');
      expect(c.state, isA<InvitationLoadError>());
    });
  });

  group('error mapping', () {
    test('INVITATION_EXPIRED -> InvitationExpired', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('INVITATION_EXPIRED', 410)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationExpired>());
    });

    test('INVITATION_REVOKED -> InvitationRevoked', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('INVITATION_REVOKED', 410)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationRevoked>());
    });

    test('INVITATION_CONTACT_MISMATCH -> InvitationWrongAccount', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('INVITATION_CONTACT_MISMATCH', 403)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationWrongAccount>());
    });

    test('INVITATION_CONTACT_UNVERIFIED -> InvitationUnverified', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('INVITATION_CONTACT_UNVERIFIED', 403)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationUnverified>());
    });

    test('INVITATION_INVALID -> InvitationInvalid', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('INVITATION_INVALID', 404)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationInvalid>());
    });

    test('network error -> InvitationLoadError', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('Network error', null)));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationLoadError>());
    });
  });

  group('accept flow', () {
    test('success emits InvitationAccepted', () async {
      when(() => usecase.acceptInvitation(any()))
          .thenAnswer((_) async => Right(_fakeAccess()));
      final c = make();
      await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
      expect(c.state, isA<InvitationAccepted>());
    });

    test('failure emits InvitationAcceptError', () async {
      when(() => usecase.acceptInvitation(any())).thenAnswer(
          (_) async => Left(const ServerFailure('Server error', 500)));
      final c = make();
      await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
      expect(c.state, isA<InvitationAcceptError>());
    });
  });
}
