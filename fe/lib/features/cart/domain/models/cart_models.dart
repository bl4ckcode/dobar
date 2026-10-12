class CartItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String? imageUrl;

  const CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? imageUrl,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class Coupon {
  final String code;
  final double discount;
  final CouponType type;

  const Coupon({
    required this.code,
    required this.discount,
    required this.type,
  });

  double calculateDiscount(double subtotal) {
    return type == CouponType.percentage
        ? subtotal * (discount / 100)
        : discount;
  }
}

enum CouponType { percentage, fixed }

class Promotion {
  final String id;
  final String name;
  final String benefit;
  final String type; // cashback, discount, points
  final double value;
  final bool active;

  const Promotion({
    required this.id,
    required this.name,
    required this.benefit,
    required this.type,
    required this.value,
    this.active = false,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Promotion',
      benefit: json['benefit_text'] ?? '',
      type: json['type'] ?? 'discount',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      active: json['is_active_by_default'] ?? false,
    );
  }

  Promotion copyWith({bool? active}) {
    return Promotion(
      id: id,
      name: name,
      benefit: benefit,
      type: type,
      value: value,
      active: active ?? this.active,
    );
  }

  double? get cashbackPercentage {
    final match = RegExp(r'(\d+)%').firstMatch(benefit);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }
}

enum LocationMethod { tableNumber, spotList, freeText }

class LocationConfig {
  final LocationMethod method;
  final List<LocationSpot> spots;

  const LocationConfig({required this.method, this.spots = const []});

  factory LocationConfig.fromJson(Map<String, dynamic> json) {
    return LocationConfig(
      method: _parseMethod(json['method']),
      spots:
          (json['spots'] as List?)
              ?.map((e) => LocationSpot.fromJson(e))
              .toList() ??
          [],
    );
  }

  static LocationMethod _parseMethod(String? method) {
    switch (method) {
      case 'spot_list':
        return LocationMethod.spotList;
      case 'free_text':
        return LocationMethod.freeText;
      case 'table_number':
      default:
        return LocationMethod.tableNumber;
    }
  }
}

class LocationSpot {
  final String id;
  final String name;

  const LocationSpot({required this.id, required this.name});

  factory LocationSpot.fromJson(Map<String, dynamic> json) {
    return LocationSpot(
      id: json['id'].toString(),
      name: json['name'] as String,
    );
  }
}
