class LiveOrderItem {
  final int? id;
  final int? orderId;
  final int? menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime? createdAt;

  LiveOrderItem({
    this.id,
    this.orderId,
    this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.createdAt,
  });

  factory LiveOrderItem.fromJson(Map<String, dynamic> json) {
    return LiveOrderItem(
      id: json['id'] as int?,
      orderId: json['order_id'] as int?,
      menuItemId: json['menu_item_id'] as int?,
      name: json['menu_item_name'] ?? json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'menu_item_name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class LiveOrderModel {
  final String id;
  final int? userId;
  final int? barId;
  final String customerName;
  final String status;
  final double totalPrice;
  final double subtotal;
  final double tax;
  final double tip;
  final double deliveryFee;
  final double discount;
  final String orderType;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? estimatedReadyTime;
  final DateTime? completedAt;
  final List<LiveOrderItem> items;

  LiveOrderModel({
    required this.id,
    this.userId,
    this.barId,
    required this.customerName,
    required this.status,
    required this.totalPrice,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.tip = 0.0,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.orderType = 'dine_in',
    this.paymentMethod = '',
    this.paymentStatus = '',
    required this.createdAt,
    this.updatedAt,
    this.estimatedReadyTime,
    this.completedAt,
    this.items = const [],
  });

  LiveOrderModel copyWith({
    String? id,
    int? userId,
    int? barId,
    String? customerName,
    String? status,
    double? totalPrice,
    double? subtotal,
    double? tax,
    double? tip,
    double? deliveryFee,
    double? discount,
    String? orderType,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? estimatedReadyTime,
    DateTime? completedAt,
    List<LiveOrderItem>? items,
  }) {
    return LiveOrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      barId: barId ?? this.barId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      tip: tip ?? this.tip,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      orderType: orderType ?? this.orderType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      estimatedReadyTime: estimatedReadyTime ?? this.estimatedReadyTime,
      completedAt: completedAt ?? this.completedAt,
      items: items ?? this.items,
    );
  }

  factory LiveOrderModel.fromJson(Map<String, dynamic> json) {
    return LiveOrderModel(
      id: '${json['id']}',
      userId: json['user_id'] as int?,
      barId: json['bar_id'] as int?,
      customerName: json['customer_name'] ?? 'Walk-in',
      status: json['status'],
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      orderType: json['order_type'] ?? 'dine_in',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      estimatedReadyTime: json['estimated_ready_time'] != null
          ? DateTime.tryParse(json['estimated_ready_time'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => LiveOrderItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bar_id': barId,
      'customer_name': customerName,
      'status': status,
      'total_price': totalPrice,
      'subtotal': subtotal,
      'tax': tax,
      'tip': tip,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'order_type': orderType,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'estimated_ready_time': estimatedReadyTime?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
