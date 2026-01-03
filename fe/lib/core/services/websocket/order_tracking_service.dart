import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/services/websocket/websocket_service.dart';

/// Order status enum matching backend
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => OrderStatus.pending,
    );
  }
  
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Aguardando confirmação';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.preparing:
        return 'Em preparo';
      case OrderStatus.ready:
        return 'Pronto!';
      case OrderStatus.completed:
        return 'Entregue';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }
  
  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '⏳';
      case OrderStatus.confirmed:
        return '✅';
      case OrderStatus.preparing:
        return '👨‍🍳';
      case OrderStatus.ready:
        return '🎉';
      case OrderStatus.completed:
        return '✔️';
      case OrderStatus.cancelled:
        return '❌';
    }
  }
  
  double get progressValue {
    switch (this) {
      case OrderStatus.pending:
        return 0.0;
      case OrderStatus.confirmed:
        return 0.25;
      case OrderStatus.preparing:
        return 0.5;
      case OrderStatus.ready:
        return 0.75;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }
}

/// Event emitted when order status changes
class OrderStatusUpdate {
  final int orderId;
  final OrderStatus status;
  final String? message;
  final DateTime timestamp;

  OrderStatusUpdate({
    required this.orderId,
    required this.status,
    this.message,
    required this.timestamp,
  });

  factory OrderStatusUpdate.fromWebSocketMessage(WebSocketMessage msg) {
    return OrderStatusUpdate(
      orderId: msg.data['order_id'] ?? 0,
      status: OrderStatus.fromString(msg.data['status'] ?? 'pending'),
      message: msg.data['message'],
      timestamp: msg.timestamp,
    );
  }
}

/// Service for tracking a user's order in real-time
/// 
/// Usage:
/// ```dart
/// final tracker = OrderTrackingService(orderId: 123, token: userToken);
/// 
/// tracker.statusUpdates.listen((update) {
///   print('Order ${update.orderId} is now ${update.status.displayName}');
/// });
/// 
/// await tracker.startTracking();
/// ```
class OrderTrackingService {
  final int orderId;
  final String token;
  
  late final WebSocketService _ws;
  final _statusController = StreamController<OrderStatusUpdate>.broadcast();
  
  OrderStatus _currentStatus = OrderStatus.pending;

  OrderTrackingService({
    required this.orderId,
    required this.token,
  }) {
    // Convert https to wss for WebSocket
    final wsBaseUrl = ApiEndpoints.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    
    _ws = WebSocketService(
      baseUrl: wsBaseUrl,
      path: '/ws/orders/$orderId/status',
      token: token,
    );
    
    _ws.messages.listen(_handleMessage);
  }

  /// Stream of order status updates
  Stream<OrderStatusUpdate> get statusUpdates => _statusController.stream;
  
  /// Current order status
  OrderStatus get currentStatus => _currentStatus;
  
  /// WebSocket connection state
  Stream<WebSocketState> get connectionState => _ws.stateStream;
  
  /// Whether currently connected
  bool get isConnected => _ws.isConnected;

  /// Start tracking the order
  Future<void> startTracking() async {
    await _ws.connect();
  }

  /// Stop tracking and clean up
  Future<void> stopTracking() async {
    await _ws.dispose();
    await _statusController.close();
  }

  void _handleMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'connected':
        // Initial connection - extract current status
        final status = OrderStatus.fromString(message.data['status'] ?? 'pending');
        _updateStatus(OrderStatusUpdate(
          orderId: orderId,
          status: status,
          message: 'Conectado ao rastreamento',
          timestamp: message.timestamp,
        ));
        break;
        
      case 'status_update':
        final update = OrderStatusUpdate.fromWebSocketMessage(message);
        _updateStatus(update);
        break;
        
      default:
        debugPrint('[OrderTracking] Unknown message type: ${message.type}');
    }
  }

  void _updateStatus(OrderStatusUpdate update) {
    _currentStatus = update.status;
    _statusController.add(update);
    debugPrint('[OrderTracking] Order $orderId -> ${update.status.displayName}');
  }
}
