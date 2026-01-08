import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_platform.dart'
    if (dart.library.io) 'notification_platform_io.dart';

/// Top-level handler for background messages (required by Firebase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Handle background message - data will be available when app opens
}

/// Notification types from backend
enum NotificationType {
  orderUpdate,
  newOrder,
  promotionNearby,
  barCheckin,
  paymentComplete,
  general;

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'order_update':
        return NotificationType.orderUpdate;
      case 'new_order':
        return NotificationType.newOrder;
      case 'promotion_nearby':
        return NotificationType.promotionNearby;
      case 'bar_checkin':
        return NotificationType.barCheckin;
      case 'payment_complete':
        return NotificationType.paymentComplete;
      default:
        return NotificationType.general;
    }
  }
}

/// Parsed notification data
class BarzNotification {
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  BarzNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
  });

  factory BarzNotification.fromRemoteMessage(RemoteMessage message) {
    return BarzNotification(
      type: NotificationType.fromString(message.data['type']),
      title: message.notification?.title ?? message.data['title'] ?? 'BARZ',
      body: message.notification?.body ?? message.data['body'] ?? '',
      data: message.data,
      timestamp: message.sentTime ?? DateTime.now(),
    );
  }

  // Extract IDs for navigation
  int? get orderId => int.tryParse(data['order_id']?.toString() ?? '');
  int? get barId => int.tryParse(data['bar_id']?.toString() ?? '');
  int? get promotionId => int.tryParse(data['promotion_id']?.toString() ?? '');
}

/// Service for handling Firebase Cloud Messaging
///
/// Usage:
/// ```dart
/// final notificationService = NotificationService();
/// await notificationService.initialize();
///
/// notificationService.onNotification.listen((notification) {
///   if (notification.type == NotificationType.orderUpdate) {
///     // Navigate to order details
///   }
/// });
///
/// // Subscribe to bar promotions
/// await notificationService.subscribeToBarPromotions(barId: 123);
/// ```
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localNotifications;

  final _notificationController = StreamController<BarzNotification>.broadcast();
  final _tokenController = StreamController<String>.broadcast();

  String? _fcmToken;
  bool _initialized = false;

  // Subscribed topics for cleanup
  final Set<String> _subscribedTopics = {};

  /// Stream of incoming notifications
  Stream<BarzNotification> get onNotification => _notificationController.stream;

  /// Stream of FCM token updates (for backend registration)
  Stream<String> get onTokenRefresh => _tokenController.stream;

  /// Current FCM token
  String? get fcmToken => _fcmToken;

  /// Whether the service is initialized
  bool get isInitialized => _initialized;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('[FCM] Notifications not authorized');
      return;
    }

    // Get FCM token
    _fcmToken = await _fcm.getToken();
    if (_fcmToken != null) {
      debugPrint('[FCM] Token: ${_fcmToken!.substring(0, 20)}...');
      _tokenController.add(_fcmToken!);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _tokenController.add(token);
      debugPrint('[FCM] Token refreshed');
    });

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message open (app in background, notification tapped)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from a notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    _initialized = true;
    debugPrint('[FCM] Initialized successfully');
  }

  Future<void> _initLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications?.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle local notification tap
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            final notification = BarzNotification(
              type: NotificationType.fromString(data['type']),
              title: data['title'] ?? '',
              body: data['body'] ?? '',
              data: data,
              timestamp: DateTime.now(),
            );
            _notificationController.add(notification);
          } catch (e) {
            debugPrint('[FCM] Error parsing local notification payload: $e');
          }
        }
      },
    );

    // Create notification channel for Android (skip on web)
    if (isAndroidPlatform()) {
      const channel = AndroidNotificationChannel(
        'barz_orders',
        'Pedidos',
        description: 'Notificações de pedidos e atualizações',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          ?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = BarzNotification.fromRemoteMessage(message);
    debugPrint('[FCM] Foreground message: ${notification.type}');

    // Emit to stream
    _notificationController.add(notification);

    // Show local notification so user sees it
    _showLocalNotification(notification);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final notification = BarzNotification.fromRemoteMessage(message);
    debugPrint('[FCM] Message opened app: ${notification.type}');

    // Emit to stream for navigation handling
    _notificationController.add(notification);
  }

  Future<void> _showLocalNotification(BarzNotification notification) async {
    final androidDetails = AndroidNotificationDetails(
      'barz_orders',
      'Pedidos',
      channelDescription: 'Notificações de pedidos e atualizações',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications?.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(notification.data),
    );
  }

  // ----- Topic Subscriptions -----

  /// Subscribe to a bar's order notifications (for bar owners)
  Future<void> subscribeToBarOrders({required int barId}) async {
    final topic = 'bar_${barId}_orders';
    await _fcm.subscribeToTopic(topic);
    _subscribedTopics.add(topic);
    debugPrint('[FCM] Subscribed to $topic');
  }

  /// Unsubscribe from a bar's order notifications
  Future<void> unsubscribeFromBarOrders({required int barId}) async {
    final topic = 'bar_${barId}_orders';
    await _fcm.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
    debugPrint('[FCM] Unsubscribed from $topic');
  }

  /// Subscribe to promotions from a nearby bar (for users)
  Future<void> subscribeToBarPromotions({required int barId}) async {
    final topic = 'bar_${barId}_promotions';
    await _fcm.subscribeToTopic(topic);
    _subscribedTopics.add(topic);
    debugPrint('[FCM] Subscribed to $topic');
  }

  /// Unsubscribe from bar promotions
  Future<void> unsubscribeFromBarPromotions({required int barId}) async {
    final topic = 'bar_${barId}_promotions';
    await _fcm.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
    debugPrint('[FCM] Unsubscribed from $topic');
  }

  /// Unsubscribe from all topics (logout)
  Future<void> unsubscribeAll() async {
    for (final topic in _subscribedTopics.toList()) {
      await _fcm.unsubscribeFromTopic(topic);
    }
    _subscribedTopics.clear();
    debugPrint('[FCM] Unsubscribed from all topics');
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _notificationController.close();
    await _tokenController.close();
  }
}
