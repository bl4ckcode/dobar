import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/domain/models/user_session.dart';

part 'session_state.freezed.dart';

@freezed
sealed class SessionState with _$SessionState {
  const SessionState._();

  /// Initial state before session is loaded
  const factory SessionState.initial() = SessionInitial;

  /// Loading session data
  const factory SessionState.loading() = SessionLoading;

  /// Session is ready - user is authenticated
  const factory SessionState.ready({
    required UserSession session,

    /// Allows user to temporarily view client mode even if they have bar access
    @Default(false) bool forceClientMode,
  }) = SessionReady;

  /// Session initialization failed
  const factory SessionState.error({required String message}) = SessionError;

  /// User has logged out
  const factory SessionState.loggedOut() = SessionLoggedOut;

  /// Helper to get current session if in ready state
  UserSession? get currentSession =>
      maybeMap(ready: (state) => state.session, orElse: () => null);

  /// Check if session is ready
  bool get isReady => this is SessionReady;

  /// Get effective user type considering forceClientMode
  UserType? get effectiveUserType => maybeMap(
    ready: (state) {
      if (state.forceClientMode) return UserType.client;
      return state.session.userType;
    },
    orElse: () => null,
  );

  /// Check if currently showing business mode
  bool get isBusinessMode => effectiveUserType == UserType.business;

  /// Check if currently showing client mode
  bool get isClientMode => effectiveUserType == UserType.client;
}
