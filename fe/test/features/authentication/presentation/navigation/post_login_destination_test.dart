import 'package:barz/features/authentication/presentation/bloc/login_state.dart';
import 'package:barz/features/authentication/presentation/navigation/post_login_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending invitation has precedence over onboarding', () {
    const state =
        LoginState.success(isNewUser: true, needsOnboarding: true) as Success;

    expect(
      resolvePostLoginDestination(
        state: state,
        pendingInvitationCode: 'opaque_token_123456789',
      ),
      PostLoginDestination.invitation,
    );
  });

  test('new and incomplete users go to onboarding', () {
    const newUser = LoginState.success(isNewUser: true) as Success;
    const incomplete = LoginState.success(needsOnboarding: true) as Success;

    expect(
      resolvePostLoginDestination(state: newUser),
      PostLoginDestination.onboarding,
    );
    expect(
      resolvePostLoginDestination(state: incomplete),
      PostLoginDestination.onboarding,
    );
  });

  test('completed users go home regardless of registration fields', () {
    const state = LoginState.success(isProfileComplete: false) as Success;

    expect(
      resolvePostLoginDestination(state: state),
      PostLoginDestination.home,
    );
  });
}
