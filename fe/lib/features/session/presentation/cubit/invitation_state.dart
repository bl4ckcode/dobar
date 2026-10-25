import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';

/// All possible view states for the staff invitation acceptance journey.
/// Maps 1-to-1 with the React InvitationViewState discriminated union.
sealed class InvitationState {
  const InvitationState();
}

/// Initial state before any action — user will enter a code manually.
class InvitationManualCode extends InvitationState {
  final String initialCode;
  const InvitationManualCode({this.initialCode = ''});
}

/// Fetching preview from the server.
class InvitationLoading extends InvitationState {
  final String code;
  const InvitationLoading({required this.code});
}

/// User is not authenticated; show generic login frame. Code is retained.
class InvitationSignedOut extends InvitationState {
  final String code;
  const InvitationSignedOut({required this.code});
}

/// Authenticated and preview loaded — ready to accept.
class InvitationReady extends InvitationState {
  final String code;
  final InvitationPreview preview;
  const InvitationReady({required this.code, required this.preview});
}

/// Acceptance call in flight.
class InvitationAccepting extends InvitationState {
  final String code;
  final InvitationPreview preview;
  const InvitationAccepting({required this.code, required this.preview});
}

/// Acceptance failed; user may retry.
class InvitationAcceptError extends InvitationState {
  final String code;
  final InvitationPreview preview;
  final String message;
  const InvitationAcceptError({
    required this.code,
    required this.preview,
    required this.message,
  });
}

/// Accepted — server confirmed BarAccess.
class InvitationAccepted extends InvitationState {
  final String code;
  final InvitationPreview preview;
  final BarAccess access;
  const InvitationAccepted({
    required this.code,
    required this.preview,
    required this.access,
  });
}

/// Already a member (same recipient replays): return current access.
class InvitationAlreadyMember extends InvitationState {
  final String code;
  final BarAccess access;
  const InvitationAlreadyMember({required this.code, required this.access});
}

/// Authenticated but wrong account (contact mismatch).
class InvitationWrongAccount extends InvitationState {
  final String code;
  const InvitationWrongAccount({required this.code});
}

/// Authenticated but contact is unverified.
class InvitationUnverified extends InvitationState {
  final String code;
  final String contactType; // 'email' or 'phone'
  const InvitationUnverified({
    required this.code,
    required this.contactType,
  });
}

/// Invitation has expired.
class InvitationExpired extends InvitationState {
  final String code;
  const InvitationExpired({required this.code});
}

/// Invitation was revoked.
class InvitationRevoked extends InvitationState {
  final String code;
  const InvitationRevoked({required this.code});
}

/// Code is invalid or was used by another user.
class InvitationInvalid extends InvitationState {
  final String code;
  const InvitationInvalid({required this.code});
}

/// Network/load error; user may retry.
class InvitationLoadError extends InvitationState {
  final String code;
  final String message;
  const InvitationLoadError({required this.code, required this.message});
}
