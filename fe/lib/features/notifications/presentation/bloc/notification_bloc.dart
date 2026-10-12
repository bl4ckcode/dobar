import 'package:barz/features/notifications/domain/repositories/abstract_notification_repository.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_event.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final AbstractNotificationRepository repository;

  NotificationBloc({required this.repository}) : super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<MarkNotificationAsRead>(_onMarkAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllAsRead);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    if (event.refresh) {
      emit(NotificationLoading());
    } else if (state is NotificationInitial) {
      emit(NotificationLoading());
    }

    final offset =
        (state is NotificationLoaded && !event.refresh)
            ? (state as NotificationLoaded).notifications.length
            : 0;

    final result = await repository.getNotifications(offset: offset);

    result.fold(
      (failure) => emit(NotificationError(failure.errorMessage)),
      (notifications) {
        if (state is NotificationLoaded && !event.refresh) {
          final current = state as NotificationLoaded;
          final updated = List.of(current.notifications)..addAll(notifications);
          emit(
            NotificationLoaded(
              notifications: updated,
              hasReachedMax: notifications.isEmpty,
              unreadCount: updated.where((n) => !n.isRead).length,
            ),
          );
        } else {
          emit(
            NotificationLoaded(
              notifications: notifications,
              hasReachedMax: notifications.length < 50,
              unreadCount: notifications.where((n) => !n.isRead).length,
            ),
          );
        }
      },
    );
  }

  Future<void> _onMarkAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;

    final result = await repository.markAsRead(event.notificationId);

    result.fold(
      (failure) => null, // Silently fail or handle error
      (_) {
        final updated =
            current.notifications.map((n) {
              if (n.id == event.notificationId) {
                return n.copyWith(isRead: true);
              }
              return n;
            }).toList();

        emit(
          current.copyWith(
            notifications: updated,
            unreadCount: updated.where((n) => !n.isRead).length,
          ),
        );
      },
    );
  }

  Future<void> _onMarkAllAsRead(
    MarkAllNotificationsAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;

    final result = await repository.markAllAsRead();

    result.fold(
      (failure) => emit(NotificationError(failure.errorMessage)),
      (_) {
        final updated =
            current.notifications.map((n) => n.copyWith(isRead: true)).toList();

        emit(current.copyWith(notifications: updated, unreadCount: 0));
      },
    );
  }
}
