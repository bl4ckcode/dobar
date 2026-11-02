import 'package:barz/features/session/domain/models/pending_invitation.dart';
import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/repositories/session_repository.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/features/session/domain/models/user_session.dart';

class SessionUsecase {
  final SessionRepository _sessionRepository;
  final UserRepository _userRepository;

  SessionUsecase({
    required this._sessionRepository,
    required this._userRepository,
  });

  /// Initialize a full user session with profile and bar access
  ///
  /// User type is determined by the `user_type` field from the profile,
  /// not by checking if they have bar access.
  Future<Either<Failure, UserSession>> initializeSession() async {
    final userResult = await _userRepository.getCurrentUser();
    return userResult.fold((failure) => Left(failure), (user) async {
      final barsResult = await _sessionRepository.getMyBars();
      return barsResult.fold((failure) => Left(failure), (bars) async {
        final invitations = await _sessionRepository.getPendingInvitations();
        return invitations.fold(
          (failure) => Left(failure),
          (pending) => Right(
            UserSession(
              user: user,
              barAccess: bars,
              activeBar: bars.isEmpty ? null : bars.first,
              pendingInvitations: pending,
            ),
          ),
        );
      });
    });
  }

  Future<Either<Failure, List<PendingInvitation>>> getPendingInvitations() =>
      _sessionRepository.getPendingInvitations();

  /// Refresh bar access list
  Future<Either<Failure, List<BarAccess>>> refreshBarAccess() {
    return _sessionRepository.getMyBars();
  }

  /// Accept a staff invitation
  Future<Either<Failure, BarAccess>> acceptInvitation(String invitationCode) {
    return _sessionRepository.acceptInvitation(invitationCode);
  }

  /// Preview invitation details (recipient-bound; authenticated only)
  Future<Either<Failure, InvitationPreview>> previewInvitation(
    String invitationCode,
  ) {
    return _sessionRepository.previewInvitation(invitationCode);
  }
}
