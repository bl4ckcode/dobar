import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/notifications/domain/models/notification_model.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractNotificationRepository {
  Future<Either<Failure, List<NotificationModel>>> getNotifications({
    int limit = 50,
    int offset = 0,
  });
  Future<Either<Failure, bool>> markAsRead(int notificationId);
  Future<Either<Failure, int>> markAllAsRead();
}
