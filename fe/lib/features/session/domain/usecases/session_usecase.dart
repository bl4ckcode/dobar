import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/rbac/user_type.dart';
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
  }) : _sessionRepository = sessionRepository,
       _userRepository = userRepository;

  /// Initialize a full user session with profile and bar access
  ///
  /// User type is determined by the `user_type` field from the profile,
  /// not by checking if they have bar access.
  Future<Either<Failure, UserSession>> initializeSession() async {
    // Get the user profile - this contains the authoritative user_type
    final userResult = await _userRepository.getCurrentUser();

    return userResult.fold((failure) => Left(failure), (user) async {
      // Only fetch bar access if user is a business user
      if (user.userType.isBusiness) {
        final barsResult = await _sessionRepository.getMyBars();

        return barsResult.fold(
          (failure) {
            // If bars fail but user succeeded, create session without bar access
            return Right(UserSession(user: user, barAccess: const []));
          },
          (bars) {
            return Right(
              UserSession(
                user: user,
                barAccess: bars,
                activeBar: bars.isNotEmpty ? bars.first : null,
              ),
            );
          },
        );
      }

      // Client users don't need bar access
      return Right(UserSession(user: user, barAccess: const []));
    });
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
