import 'dart:async';
import 'package:barz/core/router/app_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/services/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';

/// Handler for navigating when a notification is received or tapped
class NotificationNavigationHandler {
  final NotificationService _notificationService;
  StreamSubscription<BarzNotification>? _subscription;

  NotificationNavigationHandler({required NotificationService notificationService})
      : _notificationService = notificationService;

  /// Start listening for notification events
  void init() {
    _subscription = _notificationService.onNotification.listen(_handleNotification);
    debugPrint('[NotificationHandler] Initialized and listening');
  }

  void _handleNotification(BarzNotification notification) {
    debugPrint('[NotificationHandler] Handling notification: ${notification.type}');
    
    // Only handle order updates for now (DOB-35)
    if (notification.type == NotificationType.orderUpdate || 
        notification.type == NotificationType.newOrder) {
      final orderId = notification.orderId;
      if (orderId != null) {
        debugPrint('[NotificationHandler] Navigating to order $orderId');
        
        // Use the root navigator to push the order tracking page
        // AppRoute.pushOrder uses context, so we might need a context-less way 
        // if this was purely global, but since we're in the UI shell usually 
        // we can use the appRouter directly if it's exported.
        
        appRouter.push(AppRoute.order.path.replaceFirst(':orderId', orderId.toString()));
      }
    }
  }

  /// Clean up
  void dispose() {
    _subscription?.cancel();
  }
}
