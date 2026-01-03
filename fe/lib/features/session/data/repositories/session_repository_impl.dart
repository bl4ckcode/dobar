import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/session/data/datasources/session_datasource.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final SessionDatasource _datasource;

  SessionRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<BarAccess>>> getMyBars() async {
    try {
      final result = await _datasource.getMyBars();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, BarAccess>> acceptInvitation(String invitationCode) async {
    try {
      final result = await _datasource.acceptInvitation(invitationCode);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}
