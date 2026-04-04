import 'package:barz/core/design/components/barz_card.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/utils/date_time_utils.dart';
import 'package:barz/features/notifications/domain/models/notification_model.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_event.dart';
import 'package:barz/features/notifications/presentation/bloc/notification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<NotificationBloc>().add(
      const LoadNotifications(refresh: true),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<NotificationBloc>().add(const LoadNotifications());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.labelPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: colors.labelPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state is NotificationLoaded && state.unreadCount > 0) {
                return TextButton(
                  onPressed: () {
                    context.read<NotificationBloc>().add(
                      MarkAllNotificationsAsRead(),
                    );
                  },
                  child: Text(
                    'Mark all as read',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.labelSelected,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationInitial ||
              (state is NotificationLoading && state is! NotificationLoaded)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    size: 48,
                    color: colors.labelSecondary,
                  ),
                  const SizedBox(height: BarzSpacing.md),
                  Text(state.message, style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.read<NotificationBloc>().add(
                      const LoadNotifications(refresh: true),
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationLoaded) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.bellOff,
                      size: 64,
                      color: colors.labelSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: BarzSpacing.md),
                    Text(
                      'No notifications yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.labelSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<NotificationBloc>().add(
                  const LoadNotifications(refresh: true),
                );
              },
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(BarzSpacing.md),
                itemCount: state.hasReachedMax
                    ? state.notifications.length
                    : state.notifications.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: BarzSpacing.sm),
                itemBuilder: (context, index) {
                  if (index >= state.notifications.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(BarzSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final notification = state.notifications[index];
                  return _NotificationItem(notification: notification);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;

    return BarzCard.glass(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationBloc>().add(
            MarkNotificationAsRead(notification.id),
          );
        }
        // Handle navigation based on reference_id if needed
      },
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationIcon(type: notification.type),
              const SizedBox(width: BarzSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: notification.isRead
                                  ? colors.labelSecondary
                                  : colors.labelPrimary,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          DateTimeUtils.timeAgo(notification.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.labelSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BarzSpacing.xxs),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: notification.isRead
                            ? colors.labelSecondary.withValues(alpha: 0.7)
                            : colors.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!notification.isRead)
            Positioned(
                  right: 0,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.labelSelected,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.labelSelected.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 1.seconds,
                )
                .fadeIn(duration: 1.seconds),
        ],
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.orderUpdate:
        icon = LucideIcons.shoppingBag;
        color = Colors.blue;
        break;
      case NotificationType.promotion:
        icon = LucideIcons.ticket;
        color = colors.labelSelected;
        break;
      case NotificationType.system:
        icon = LucideIcons.info;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(BarzSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BarzSpacing.xs),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
