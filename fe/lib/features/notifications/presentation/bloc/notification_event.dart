import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationEvent {
  final bool refresh;
  const LoadNotifications({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class MarkNotificationAsRead extends NotificationEvent {
  final int notificationId;
  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsAsRead extends NotificationEvent {}
