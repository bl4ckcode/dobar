import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';

part 'session_event.freezed.dart';

@freezed
sealed class SessionEvent with _$SessionEvent {
  /// Initialize session after login - fetches user profile and bar access
  const factory SessionEvent.initialize() = InitializeSession;

  /// Refresh bar access list from API
  const factory SessionEvent.refreshBarAccess() = RefreshBarAccess;

  /// Switch the active bar for business users
  const factory SessionEvent.switchActiveBar({required int barId}) =
      SwitchActiveBar;

  /// Accept a staff invitation using invitation code
  const factory SessionEvent.acceptInvitation({
    required String invitationCode,
  }) = AcceptInvitation;

  /// Handle when a new bar is created (user becomes owner)
  const factory SessionEvent.barCreated({required BarAccess newBar}) =
      BarCreated;

  /// Clear session on logout
  const factory SessionEvent.logout() = LogoutSession;

  /// Force switch to client mode (even if user has bar access)
  const factory SessionEvent.switchToClientMode() = SwitchToClientMode;

  /// Force switch to business mode (if user has bar access)
  const factory SessionEvent.switchToBusinessMode() = SwitchToBusinessMode;
}
