import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/repositories/session_repository.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/features/session/domain/models/user_session.dart';

class SessionUsecase {
  final SessionRepository _sessionRepository;
  final UserRepository _userRepository;

  SessionUsecase({
    required SessionRepository sessionRepository,
    required UserRepository userRepository,
  })  : _sessionRepository = sessionRepository,
        _userRepository = userRepository;

  /// Initialize a full user session with profile and bar access
  Future<Either<Failure, UserSession>> initializeSession() async {
    // First, get the user profile
    final userResult = await _userRepository.getCurrentUser();

    return userResult.fold(
      (failure) => Left(failure),
      (user) async {
        // Then, get bar access
        final barsResult = await _sessionRepository.getMyBars();

        return barsResult.fold(
          (failure) {
            // If bars fail but user succeeded, create session without bar access
            // This is valid for client users
            return Right(UserSession(
              user: user,
              barAccess: const [],
            ));
          },
          (bars) {
            return Right(UserSession(
              user: user,
              barAccess: bars,
              activeBar: bars.isNotEmpty ? bars.first : null,
            ));
          },
        );
      },
    );
  }

  /// Refresh bar access list
  Future<Either<Failure, List<BarAccess>>> refreshBarAccess() {
    return _sessionRepository.getMyBars();
  }

  /// Accept a staff invitation
  Future<Either<Failure, BarAccess>> acceptInvitation(String invitationCode) {
    return _sessionRepository.acceptInvitation(invitationCode);
  }
}
