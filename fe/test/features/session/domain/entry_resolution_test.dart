import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/entry_destination.dart';
import 'package:barz/features/session/domain/models/invitation_intent.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/models/pending_invitation.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/session/domain/repositories/session_repository.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SessionRepository extends Mock implements SessionRepository {}

class _UserRepository extends Mock implements UserRepository {}

const access = BarAccess(
  barId: 42,
  barName: 'Venue',
  role: BarRole.staff,
  permissions: {},
);
final invitation = PendingInvitation(
  id: 1,
  barId: 42,
  code: 'CaseSensitive_Token123',
  preview: InvitationPreview(
    venueName: 'Venue',
    role: 'staff',
    maskedRecipient: 's***@test.com',
    expiresAt: DateTime(2030),
    permissions: const [],
  ),
);

void main() {
  test('legacy business without access returns to editable onboarding', () {
    final session = UserSession(
      user: UserModel(
        userType: UserType.business,
        countryCode: 'BR',
        hasSelectedUserType: true,
      ),
    );
    expect(resolveEntry(session), EntryDestination.onboarding);
    expect(session.user.countryCode, 'BR');
    expect(session.user.userType, UserType.business);
  });
  test(
    'completed customer returns home; missing selection enters onboarding',
    () {
      expect(
        resolveEntry(
          UserSession(
            user: UserModel(countryCode: 'BR', hasSelectedUserType: true),
          ),
        ),
        EntryDestination.customer,
      );
      expect(
        resolveEntry(UserSession(user: UserModel())),
        EntryDestination.onboarding,
      );
    },
  );
  test('accepted staff access precedes incomplete onboarding', () {
    expect(
      resolveEntry(UserSession(user: UserModel(), barAccess: const [access])),
      EntryDestination.workspace,
    );
  });
  test('explicit, single and multiple invitations precede access and role', () {
    final session = UserSession(user: UserModel(), barAccess: const [access]);
    expect(
      resolveEntry(session, invitationCode: 'CaseSensitive_Token123'),
      EntryDestination.invitation,
    );
    expect(
      resolveEntry(
        UserSession(user: UserModel(), pendingInvitations: [invitation]),
      ),
      EntryDestination.invitation,
    );
    expect(
      resolveEntry(
        UserSession(
          user: UserModel(),
          pendingInvitations: [invitation, invitation],
        ),
      ),
      EntryDestination.chooser,
    );
  });
  test('session always fetches access even with incomplete profile', () async {
    final users = _UserRepository();
    final sessions = _SessionRepository();
    when(users.getCurrentUser).thenAnswer((_) async => Right(UserModel()));
    when(sessions.getMyBars).thenAnswer((_) async => const Right([access]));
    when(
      sessions.getPendingInvitations,
    ).thenAnswer((_) async => const Right([]));
    final result = await SessionUsecase(
      sessionRepository: sessions,
      userRepository: users,
    ).initializeSession();
    expect(
      result.getOrElse(() => throw StateError('unexpected failure')).barAccess,
      [access],
    );
  });
  test('access and discovery failures stay failures', () async {
    final users = _UserRepository();
    final sessions = _SessionRepository();
    when(users.getCurrentUser).thenAnswer((_) async => Right(UserModel()));
    when(
      sessions.getMyBars,
    ).thenAnswer((_) async => const Left(ServerFailure('unavailable', 503)));
    final usecase = SessionUsecase(
      sessionRepository: sessions,
      userRepository: users,
    );
    expect((await usecase.initializeSession()).isLeft(), true);
    verifyNever(sessions.getPendingInvitations);
    when(sessions.getMyBars).thenAnswer((_) async => const Right([]));
    when(
      sessions.getPendingInvitations,
    ).thenAnswer((_) async => const Left(ServerFailure('unavailable', 503)));
    expect((await usecase.initializeSession()).isLeft(), true);
  });
  test('links reject unrelated paths and hosts and retain opaque case', () {
    const token = 'MiXeD_Case_Token-123';
    expect(
      parseInvitationCode(
        'https://dobar.app/staff/invitations/accept?code=$token',
      ),
      token,
    );
    expect(parseInvitationCode('https://dobar.app/convite/$token'), token);
    expect(parseInvitationCode('https://dobar.app/convite/$token/'), token);
    for (final url in [
      'https://evil.com/convite/$token',
      'https://dobar.app/other?code=$token',
      'http://dobar.app/convite/$token',
      'https://dobar.app:8443/convite/$token',
    ]) {
      expect(parseInvitationCode(url), null);
    }
  });
}
