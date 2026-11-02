import 'dart:async';
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
  barId: 42,
  barName: 'Bar Teste',
  role: BarRole.cashier,
  permissions: {},
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
    sessionUsecase: usecase,
    sessionBloc: bloc,
    initialCode: code,
    isAuthenticated: () async => true,
  );

  group('code parsing', () {
    test('accepts bare DBR code and calls previewInvitation', () async {
      when(
        () => usecase.previewInvitation(any()),
      ).thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('normalizes DBR without hyphens', () async {
      when(
        () => usecase.previewInvitation(any()),
      ).thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('DBR7K4M29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('extracts code from dobar.app link', () async {
      when(
        () => usecase.previewInvitation(any()),
      ).thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('https://dobar.app/convite/DBR-7K4M-29QX');
      verify(() => usecase.previewInvitation('DBR-7K4M-29QX')).called(1);
    });

    test('accepts backend opaque URL-safe token', () async {
      when(
        () => usecase.previewInvitation(any()),
      ).thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode('A1b2C3d4E5f6G7h8I9_j-k');
      verify(
        () => usecase.previewInvitation('A1b2C3d4E5f6G7h8I9_j-k'),
      ).called(1);
    });

    test('extracts code from canonical invitation link', () async {
      when(
        () => usecase.previewInvitation(any()),
      ).thenAnswer((_) async => Right(_fakePreview()));
      final c = make();
      await c.submitCode(
        'https://dobar.app/staff/invitations/accept?code=A1b2C3d4E5f6G7h8I9_j-k',
      );
      verify(
        () => usecase.previewInvitation('A1b2C3d4E5f6G7h8I9_j-k'),
      ).called(1);
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
        (_) async => Left(const ServerFailure('INVITATION_EXPIRED', 410)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationExpired>());
    });

    test('INVITATION_REVOKED -> InvitationRevoked', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async => Left(const ServerFailure('INVITATION_REVOKED', 410)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationRevoked>());
    });

    test('INVITATION_CONTACT_MISMATCH -> InvitationWrongAccount', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async =>
            Left(const ServerFailure('INVITATION_CONTACT_MISMATCH', 403)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationWrongAccount>());
    });

    test('INVITATION_CONTACT_UNVERIFIED -> InvitationUnverified', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async =>
            Left(const ServerFailure('INVITATION_CONTACT_UNVERIFIED', 403)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationUnverified>());
    });

    test('unverified contact preserves server phone metadata', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async => Left(
          const ServerFailure(
            'INVITATION_CONTACT_UNVERIFIED',
            403,
            details: {
              'contact_type': ['phone'],
            },
          ),
        ),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(
        c.state,
        isA<InvitationUnverified>().having(
          (state) => state.contactType,
          'contactType',
          'phone',
        ),
      );
    });

    test('INVITATION_INVALID -> InvitationInvalid', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async => Left(const ServerFailure('INVITATION_INVALID', 404)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationInvalid>());
    });

    test('network error -> InvitationLoadError', () async {
      when(() => usecase.previewInvitation(any())).thenAnswer(
        (_) async => Left(const ServerFailure('Network error', null)),
      );
      final c = make();
      await c.submitCode('DBR-7K4M-29QX');
      expect(c.state, isA<InvitationLoadError>());
    });
  });

  test('refresh failure retries exact venue without accepting again', () async {
    when(
      () => usecase.acceptInvitation(any()),
    ).thenAnswer((_) async => Right(_fakeAccess()));
    when(
      () => bloc.initializeForEntry(),
    ).thenAnswer((_) async => const SessionState.initial());
    var attempts = 0;
    when(
      () => bloc.refreshAndSelectVenue(42),
    ).thenAnswer((_) async => ++attempts > 1);
    final c = make();
    await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
    expect(await c.enterWorkspace(42), false);
    expect(await c.enterWorkspace(42), true);
    verify(() => usecase.acceptInvitation(any())).called(1);
    verify(() => bloc.refreshAndSelectVenue(42)).called(2);
  });
  test(
    'duplicate accept taps issue one request and clear intent after confirmation',
    () async {
      final result = Completer<Either<Failure, BarAccess>>();
      when(
        () => usecase.acceptInvitation(any()),
      ).thenAnswer((_) => result.future);
      String? saved = 'DBR-7K4M-29QX';
      final c = InvitationCubit(
        sessionUsecase: usecase,
        sessionBloc: bloc,
        persistIntent: (code) async {
          saved = code;
        },
      );
      final first = c.acceptInvitation(saved!, _fakePreview());
      await c.acceptInvitation(saved!, _fakePreview());
      expect(saved, isNotNull);
      result.complete(Right(_fakeAccess()));
      await first;
      expect(saved, null);
      await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
      verify(() => usecase.acceptInvitation(any())).called(1);
    },
  );

  test('new warm invitation supersedes an older in-flight preview', () async {
    final old = Completer<Either<Failure, InvitationPreview>>();
    when(
      () => usecase.previewInvitation('Old_CaseSensitive123'),
    ).thenAnswer((_) => old.future);
    final latest = _fakePreview();
    when(
      () => usecase.previewInvitation('New_CaseSensitive123'),
    ).thenAnswer((_) async => Right(latest));
    final c = make();
    final first = c.submitCode('Old_CaseSensitive123');
    await Future<void>.delayed(Duration.zero);
    await c.submitCode('New_CaseSensitive123');
    old.complete(Right(_fakePreview()));
    await first;
    expect((c.state as InvitationReady).code, 'New_CaseSensitive123');
    await c.close();
  });

  group('accept flow', () {
    test('success emits InvitationAccepted', () async {
      when(
        () => usecase.acceptInvitation(any()),
      ).thenAnswer((_) async => Right(_fakeAccess()));
      final c = make();
      await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
      expect(c.state, isA<InvitationAccepted>());
    });

    test('failure emits InvitationAcceptError', () async {
      when(
        () => usecase.acceptInvitation(any()),
      ).thenAnswer((_) async => Left(const ServerFailure('Server error', 500)));
      final c = make();
      await c.acceptInvitation('DBR-7K4M-29QX', _fakePreview());
      expect(c.state, isA<InvitationAcceptError>());
    });
  });
}
