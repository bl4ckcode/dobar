class OrderItemModel {
  final int id;
  final int orderId;
  final int menuItemId;
  final String menuItemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.menuItemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      orderId: json['order_id'],
      menuItemId: json['menu_item_id'],
      menuItemName: json['menu_item_name'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'menu_item_name': menuItemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class OrderModel {
  final int id;
  final int userId;
  final int barId;
  final String status;
  final String orderType;
  final String paymentMethod;
  final double subtotal;
  final double tax;
  final double tip;
  final double deliveryFee;
  final double discount;
  final double totalPrice;
  final List<OrderItemModel> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? estimatedReadyTime;
  final List<StatusHistory>? statusHistory;

  OrderModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.status,
    required this.orderType,
    required this.paymentMethod,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.deliveryFee,
    required this.discount,
    required this.totalPrice,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedReadyTime,
    this.statusHistory,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      userId: json['user_id'],
      barId: json['bar_id'],
      status: json['status'],
      orderType: json['order_type'],
      paymentMethod: json['payment_method'],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num).toDouble(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      estimatedReadyTime: json['estimated_ready_time'] != null
          ? DateTime.parse(json['estimated_ready_time'])
          : null,
      statusHistory: (json['status_history'] as List<dynamic>?)
          ?.map((e) => StatusHistory.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bar_id': barId,
      'status': status,
      'order_type': orderType,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'tax': tax,
      'tip': tip,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'total_price': totalPrice,
      'items': items.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'estimated_ready_time': estimatedReadyTime?.toIso8601String(),
    };
  }
}

class StatusHistory {
  final String status;
  final DateTime timestamp;

  StatusHistory({required this.status, required this.timestamp});

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class PaginatedOrders {
  final List<OrderModel> orders;
  final int total;
  final int page;
  final int pageSize;

  PaginatedOrders({
    required this.orders,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PaginatedOrders.fromJson(Map<String, dynamic> json) {
    return PaginatedOrders(
      orders: (json['orders'] as List<dynamic>)
          .map((e) => OrderModel.fromJson(e))
          .toList(),
      total: json['total'],
      page: json['page'],
      pageSize: json['page_size'],
    );
  }
}
