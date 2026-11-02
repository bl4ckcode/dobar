import 'user_session.dart';

enum EntryDestination { invitation, chooser, workspace, onboarding, customer }

EntryDestination resolveEntry(
  UserSession session, {
  String? invitationCode,
  bool forceClientMode = false,
}) {
  if (invitationCode?.isNotEmpty == true) return EntryDestination.invitation;
  if (session.pendingInvitations.length == 1) {
    return EntryDestination.invitation;
  }
  if (session.pendingInvitations.length > 1) return EntryDestination.chooser;
  if (session.barAccess.isNotEmpty && !forceClientMode) {
    return EntryDestination.workspace;
  }
  if (session.barAccess.isEmpty &&
      (session.isBusiness || !session.user.hasCompletedOnboarding)) {
    return EntryDestination.onboarding;
  }
  return EntryDestination.customer;
}
