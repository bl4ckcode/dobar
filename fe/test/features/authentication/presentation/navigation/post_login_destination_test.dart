import 'package:barz/features/session/domain/models/entry_destination.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'explicit intent precedes incomplete profile for every login method',
    () {
      for (final method in ['phone', 'google', 'apple', 'mfa', 'restored']) {
        expect(
          resolveEntry(
            UserSession(user: UserModel()),
            invitationCode: 'CaseSensitive_Token123',
          ),
          EntryDestination.invitation,
          reason: method,
        );
      }
    },
  );
  test('business profile without actual access needs editable setup', () {
    expect(
      resolveEntry(
        UserSession(
          user: UserModel(
            userType: UserType.business,
            countryCode: 'BR',
            hasSelectedUserType: true,
          ),
        ),
      ),
      EntryDestination.onboarding,
    );
  });
}
