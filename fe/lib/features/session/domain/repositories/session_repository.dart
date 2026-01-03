import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';

abstract class SessionRepository {
  /// Fetch all bars the user has access to
  Future<Either<Failure, List<BarAccess>>> getMyBars();

  /// Accept a staff invitation using invitation code
  Future<Either<Failure, BarAccess>> acceptInvitation(String invitationCode);
}
