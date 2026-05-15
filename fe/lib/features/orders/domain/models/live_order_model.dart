class LiveOrderItem {
  final String name;
  final int quantity;
  final double price;

  LiveOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory LiveOrderItem.fromJson(Map<String, dynamic> json) {
    return LiveOrderItem(
      name: json['menu_item_name'] ?? json['name'],
      quantity: json['quantity'] ?? 1,
      price: (json['unit_price'] as num?)?.toDouble() ??
          (json['total_price'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'price': price};
  }
}

class LiveOrderModel {
  final String id;
  final String customerName;
  final String status;
  final double total;
  final DateTime createdAt;
  final List<LiveOrderItem> items;

  LiveOrderModel({
    required this.id,
    required this.customerName,
    required this.status,
    required this.total,
    required this.createdAt,
    this.items = const [],
  });

  LiveOrderModel copyWith({
    String? id,
    String? customerName,
    String? status,
    double? total,
    DateTime? createdAt,
    List<LiveOrderItem>? items,
  }) {
    return LiveOrderModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  factory LiveOrderModel.fromJson(Map<String, dynamic> json) {
    return LiveOrderModel(
      id: '${json['id']}',
      customerName: json['customer_name'] ?? 'Walk-in',
      status: json['status'],
      total: (json['total_price'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0.0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
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
      'customer_name': customerName,
      'status': status,
      'total_price': total,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
