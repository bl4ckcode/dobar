import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/notifications/data/data_sources/notification_network_datasource.dart';
import 'package:barz/features/notifications/domain/models/notification_model.dart';
import 'package:barz/features/notifications/domain/repositories/abstract_notification_repository.dart';
import 'package:dartz/dartz.dart';

class NotificationRepositoryImpl implements AbstractNotificationRepository {
  final NotificationNetworkDataSource dataSource;

  NotificationRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final notifications = await dataSource.getNotifications(
        limit: limit,
        offset: offset,
      );
      return Right(notifications);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, bool>> markAsRead(int notificationId) async {
    try {
      await dataSource.markAsRead(notificationId);
      return const Right(true);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async {
    try {
      final count = await dataSource.markAllAsRead();
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}
