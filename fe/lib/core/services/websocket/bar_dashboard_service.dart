import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/services/websocket/websocket_service.dart';
import 'package:barz/core/services/websocket/order_tracking_service.dart';

/// Incoming order for bar owner dashboard
class IncomingOrder {
  final int orderId;
  final int userId;
  final String userName;
  final String? tableNumber;
  final List<OrderLineItem> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? notes;

  IncomingOrder({
    required this.orderId,
    required this.userId,
    required this.userName,
    this.tableNumber,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  factory IncomingOrder.fromJson(Map<String, dynamic> json) {
    return IncomingOrder(
      orderId: json['order_id'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Cliente',
      tableNumber: json['table_number'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderLineItem.fromJson(e))
              .toList() ??
          [],
      totalAmount: (json['total_amount'] ?? json['total'] ?? 0).toDouble(),
      status: OrderStatus.fromString(json['status'] ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }

  IncomingOrder copyWith({OrderStatus? status}) {
    return IncomingOrder(
      orderId: orderId,
      userId: userId,
      userName: userName,
      tableNumber: tableNumber,
      items: items,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      notes: notes,
    );
  }
}

/// Line item in an order
class OrderLineItem {
  final int menuItemId;
  final String name;
  final int quantity;
  final double price;
  final String? notes;

  OrderLineItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.notes,
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      menuItemId: json['menu_item_id'] ?? json['item_id'] ?? 0,
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      notes: json['notes'],
    );
  }

  double get subtotal => price * quantity;
}

/// Events for bar owner dashboard
sealed class DashboardEvent {}

class NewOrderEvent extends DashboardEvent {
  final IncomingOrder order;
  NewOrderEvent(this.order);
}

class OrderUpdatedEvent extends DashboardEvent {
  final int orderId;
  final OrderStatus newStatus;
  OrderUpdatedEvent(this.orderId, this.newStatus);
}

class OrderCancelledEvent extends DashboardEvent {
  final int orderId;
  final String? reason;
  OrderCancelledEvent(this.orderId, this.reason);
}

/// Service for bar owner real-time order dashboard
/// 
/// Usage:
/// ```dart
/// final dashboard = BarDashboardService(barId: 1, token: ownerToken);
/// 
/// dashboard.events.listen((event) {
///   if (event is NewOrderEvent) {
///     print('New order: ${event.order.orderId}');
///   }
/// });
/// 
/// await dashboard.connect();
/// 
/// // Confirm an order
/// dashboard.confirmOrder(orderId: 123);
/// 
/// // Mark as preparing
/// dashboard.markPreparing(orderId: 123);
/// 
/// // Mark as ready
/// dashboard.markReady(orderId: 123);
/// ```
class BarDashboardService {
  final int barId;
  final String token;

  late final WebSocketService _ws;
  final _eventsController = StreamController<DashboardEvent>.broadcast();
  final _ordersController = StreamController<List<IncomingOrder>>.broadcast();
  
  // Active orders cache
  final Map<int, IncomingOrder> _activeOrders = {};

  BarDashboardService({
    required this.barId,
    required this.token,
  }) {
    // Convert https to wss for WebSocket
    final wsBaseUrl = ApiEndpoints.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    _ws = WebSocketService(
      baseUrl: wsBaseUrl,
      path: '/ws/bar/$barId/orders',
      token: token,
    );

    _ws.messages.listen(_handleMessage);
  }

  /// Stream of dashboard events (new orders, updates, cancellations)
  Stream<DashboardEvent> get events => _eventsController.stream;
  
  /// Stream of active orders list (updated whenever orders change)
  Stream<List<IncomingOrder>> get ordersStream => _ordersController.stream;
  
  /// Current list of active orders
  List<IncomingOrder> get activeOrders => _activeOrders.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Connection state
  Stream<WebSocketState> get connectionState => _ws.stateStream;
  
  /// Whether currently connected
  bool get isConnected => _ws.isConnected;

  /// Connect to dashboard
  Future<void> connect() async {
    await _ws.connect();
  }

  /// Disconnect and clean up
  Future<void> dispose() async {
    await _ws.dispose();
    await _eventsController.close();
    await _ordersController.close();
  }

  // ----- Order Actions -----

  /// Confirm a pending order
  void confirmOrder({required int orderId}) {
    _sendAction('confirm', orderId);
  }

  /// Mark order as being prepared
  void markPreparing({required int orderId}) {
    _sendAction('prepare', orderId);
  }

  /// Mark order as ready for pickup/delivery
  void markReady({required int orderId}) {
    _sendAction('ready', orderId);
  }

  /// Mark order as completed (delivered)
  void markCompleted({required int orderId}) {
    _sendAction('complete', orderId);
  }

  /// Cancel an order with optional reason
  void cancelOrder({required int orderId, String? reason}) {
    _ws.send({
      'action': 'cancel',
      'order_id': orderId,
      'reason': reason,
    });
  }

  void _sendAction(String action, int orderId) {
    _ws.send({
      'action': action,
      'order_id': orderId,
    });
  }

  void _handleMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'connected':
        // Connection confirmed - might include initial orders
        final orders = message.data['active_orders'] as List<dynamic>?;
        if (orders != null) {
          for (final orderJson in orders) {
            final order = IncomingOrder.fromJson(orderJson);
            _activeOrders[order.orderId] = order;
          }
          _ordersController.add(activeOrders);
        }
        debugPrint('[Dashboard] Connected to bar $barId dashboard');
        break;

      case 'new_order':
        final order = IncomingOrder.fromJson(message.data);
        _activeOrders[order.orderId] = order;
        _eventsController.add(NewOrderEvent(order));
        _ordersController.add(activeOrders);
        debugPrint('[Dashboard] New order: ${order.orderId}');
        break;

      case 'order_updated':
        final orderId = message.data['order_id'] as int? ?? 0;
        final newStatus = OrderStatus.fromString(message.data['status'] ?? 'pending');
        
        if (_activeOrders.containsKey(orderId)) {
          _activeOrders[orderId] = _activeOrders[orderId]!.copyWith(status: newStatus);
          _eventsController.add(OrderUpdatedEvent(orderId, newStatus));
          _ordersController.add(activeOrders);
        }
        debugPrint('[Dashboard] Order $orderId -> ${newStatus.displayName}');
        break;

      case 'order_cancelled':
        final orderId = message.data['order_id'] as int? ?? 0;
        final reason = message.data['reason'] as String?;
        
        _activeOrders.remove(orderId);
        _eventsController.add(OrderCancelledEvent(orderId, reason));
        _ordersController.add(activeOrders);
        debugPrint('[Dashboard] Order $orderId cancelled');
        break;

      case 'order_completed':
        final orderId = message.data['order_id'] as int? ?? 0;
        _activeOrders.remove(orderId);
        _ordersController.add(activeOrders);
        debugPrint('[Dashboard] Order $orderId completed');
        break;

      default:
        debugPrint('[Dashboard] Unknown message: ${message.type}');
    }
  }
}
