class CartItemModel {
  final int id;
  final int cartId;
  final int menuItemId;
  final int barId;
  final String menuItemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  CartItemModel({
    required this.id,
    required this.cartId,
    required this.menuItemId,
    required this.barId,
    required this.menuItemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'],
      cartId: json['cart_id'],
      menuItemId: json['menu_item_id'],
      barId: json['bar_id'],
      menuItemName: json['menu_item_name'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cart_id': cartId,
      'menu_item_id': menuItemId,
      'bar_id': barId,
      'menu_item_name': menuItemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  CartItemModel copyWith({int? quantity, double? totalPrice}) {
    return CartItemModel(
      id: id,
      cartId: cartId,
      menuItemId: menuItemId,
      barId: barId,
      menuItemName: menuItemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class CartModel {
  final int id;
  final int userId;
  final List<CartItemModel> items;
  final int totalItems;
  final double subtotal;
  final DateTime createdAt;
  final DateTime updatedAt;

  CartModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalItems,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'],
      userId: json['user_id'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItemModel.fromJson(e))
              .toList() ??
          [],
      totalItems: json['total_items'] ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'items': items.map((e) => e.toJson()).toList(),
      'total_items': totalItems,
      'subtotal': subtotal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CartModel copyWith({List<CartItemModel>? items, int? totalItems, double? subtotal}) {
    return CartModel(
      id: id,
      userId: userId,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      subtotal: subtotal ?? this.subtotal,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class CheckoutResult {
  final int orderId;
  final String status;
  final double totalPrice;
  final String message;

  CheckoutResult({
    required this.orderId,
    required this.status,
    required this.totalPrice,
    required this.message,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      orderId: json['order_id'],
      status: json['status'],
      totalPrice: (json['total_price'] as num).toDouble(),
      message: json['message'],
    );
  }
}
