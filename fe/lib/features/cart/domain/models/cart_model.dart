import 'package:flutter/foundation.dart';

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
    final quantity = json['quantity'] as int;
    final unitPrice = (json['unit_price'] as num).toDouble();
    final totalPrice = json['total_price'] != null
        ? (json['total_price'] as num).toDouble()
        : quantity * unitPrice;

    return CartItemModel(
      id: json['id'] ?? 0,
      cartId: json['cart_id'] ?? 0,
      menuItemId: json['menu_item_id'],
      barId: json['bar_id'] ?? 0,
      menuItemName: json['menu_item_name'] ?? json['name'] ?? '',
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
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

  CartItemModel copyWith({int? barId, int? quantity, double? totalPrice}) {
    return CartItemModel(
      id: id,
      cartId: cartId,
      menuItemId: menuItemId,
      barId: barId ?? this.barId,
      menuItemName: menuItemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class AppliedBundleModel {
  final int bundleId;
  final String bundleName;
  final double discountAmount;
  final String message;

  AppliedBundleModel({
    required this.bundleId,
    required this.bundleName,
    required this.discountAmount,
    required this.message,
  });

  factory AppliedBundleModel.fromJson(Map<String, dynamic> json) {
    return AppliedBundleModel(
      bundleId: json['bundle_id'],
      bundleName: json['bundle_name'],
      discountAmount: (json['discount_amount'] as num).toDouble(),
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bundle_id': bundleId,
      'bundle_name': bundleName,
      'discount_amount': discountAmount,
      'message': message,
    };
  }
}

class CartSyncRequest {
  final List<CartItemInput> items;
  final String? locationIdentifier;
  final List<String>? activePromotionIds;
  final String? couponCode;

  CartSyncRequest({
    required this.items,
    this.locationIdentifier,
    this.activePromotionIds,
    this.couponCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      if (locationIdentifier != null) 'location_identifier': locationIdentifier,
      if (activePromotionIds != null)
        'active_promotion_ids': activePromotionIds,
      if (couponCode != null) 'coupon_code': couponCode,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CartSyncRequest &&
        listEquals(other.items, items) &&
        other.locationIdentifier == locationIdentifier &&
        listEquals(other.activePromotionIds, activePromotionIds) &&
        other.couponCode == couponCode;
  }

  @override
  int get hashCode {
    return items.hashCode ^
        locationIdentifier.hashCode ^
        activePromotionIds.hashCode ^
        couponCode.hashCode;
  }
}

class CartItemInput {
  final int menuItemId;
  final int quantity;
  final String? specialInstructions;

  CartItemInput({
    required this.menuItemId,
    required this.quantity,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'quantity': quantity,
      if (specialInstructions != null)
        'special_instructions': specialInstructions,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CartItemInput &&
        other.menuItemId == menuItemId &&
        other.quantity == quantity &&
        other.specialInstructions == specialInstructions;
  }

  @override
  int get hashCode =>
      menuItemId.hashCode ^ quantity.hashCode ^ specialInstructions.hashCode;
}

class ValidationIssue {
  final String severity;
  final String message;
  final String? relatedField;

  ValidationIssue({
    required this.severity,
    required this.message,
    this.relatedField,
  });

  factory ValidationIssue.fromJson(Map<String, dynamic> json) {
    return ValidationIssue(
      severity: json['severity'] ?? 'info',
      message: json['message'] ?? '',
      relatedField: json['related_field'],
    );
  }
}

class LocationStatus {
  final bool valid;
  final String? message;

  LocationStatus({required this.valid, this.message});

  factory LocationStatus.fromJson(Map<String, dynamic> json) {
    return LocationStatus(
      valid: json['valid'] ?? true,
      message: json['message'],
    );
  }
}

abstract class CartModel {
  int get id;
  int get userId;
  List<CartItemModel> get items;
  int get totalItems;
  double get subtotal;
  double get discount;
  double get tax;
  double get tip;
  double get deliveryFee;
  double get total;
  List<AppliedBundleModel> get appliedBundles;
  double get bundleSavings;
  double get subtotalAfterBundles;
  String? get bundleHint;
  List<PromotionApplied> get appliedPromotions;
  List<ValidationIssue> get validationIssues;
  LocationStatus? get locationStatus;
  DateTime get createdAt;
  DateTime get updatedAt;

  CartModel copyWith({
    List<CartItemModel>? items,
    int? totalItems,
    double? subtotal,
    double? discount,
    double? tax,
    double? tip,
    double? deliveryFee,
    double? total,
    List<AppliedBundleModel>? appliedBundles,
    double? bundleSavings,
    double? subtotalAfterBundles,
    String? bundleHint,
    List<PromotionApplied>? appliedPromotions,
    List<ValidationIssue>? validationIssues,
    LocationStatus? locationStatus,
  });

  factory CartModel({
    required int id,
    required int userId,
    required List<CartItemModel> items,
    required int totalItems,
    required double subtotal,
    double discount,
    double tax,
    double tip,
    double deliveryFee,
    double? total,
    List<AppliedBundleModel> appliedBundles,
    double bundleSavings,
    double? subtotalAfterBundles,
    String? bundleHint,
    List<PromotionApplied> appliedPromotions,
    List<ValidationIssue> validationIssues,
    LocationStatus? locationStatus,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CartModelImpl;

  factory CartModel.fromJson(Map<String, dynamic> json) =
      _CartModelImpl.fromJson;
}

class _CartModelImpl implements CartModel {
  @override
  final int id;
  @override
  final int userId;
  @override
  final List<CartItemModel> items;
  @override
  final int totalItems;
  @override
  final double subtotal;
  @override
  final double discount;
  @override
  final double tax;
  @override
  final double tip;
  @override
  final double deliveryFee;
  @override
  final double total;
  @override
  final List<AppliedBundleModel> appliedBundles;
  @override
  final double bundleSavings;
  @override
  final double subtotalAfterBundles;
  @override
  final String? bundleHint;
  @override
  final List<PromotionApplied> appliedPromotions;
  @override
  final List<ValidationIssue> validationIssues;
  @override
  final LocationStatus? locationStatus;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  _CartModelImpl({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalItems,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    this.tip = 0.0,
    this.deliveryFee = 0.0,
    double? total,
    this.appliedBundles = const [],
    this.bundleSavings = 0.0,
    double? subtotalAfterBundles,
    this.bundleHint,
    this.appliedPromotions = const [],
    this.validationIssues = const [],
    this.locationStatus,
    required this.createdAt,
    required this.updatedAt,
  }) : subtotalAfterBundles = subtotalAfterBundles ?? subtotal,
       total = total ?? subtotal;

  @override
  CartModel copyWith({
    List<CartItemModel>? items,
    int? totalItems,
    double? subtotal,
    double? discount,
    double? tax,
    double? tip,
    double? deliveryFee,
    double? total,
    List<AppliedBundleModel>? appliedBundles,
    double? bundleSavings,
    double? subtotalAfterBundles,
    String? bundleHint,
    List<PromotionApplied>? appliedPromotions,
    List<ValidationIssue>? validationIssues,
    LocationStatus? locationStatus,
  }) {
    return _CartModelImpl(
      id: id,
      userId: userId,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      tip: tip ?? this.tip,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      appliedBundles: appliedBundles ?? this.appliedBundles,
      bundleSavings: bundleSavings ?? this.bundleSavings,
      subtotalAfterBundles: subtotalAfterBundles ?? this.subtotalAfterBundles,
      bundleHint: bundleHint ?? this.bundleHint,
      appliedPromotions: appliedPromotions ?? this.appliedPromotions,
      validationIssues: validationIssues ?? this.validationIssues,
      locationStatus: locationStatus ?? this.locationStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory _CartModelImpl.fromJson(Map<String, dynamic> json) {
    return _CartModelImpl(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.where((e) => e != null && e is Map<String, dynamic>)
              .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalItems: json['total_items'] ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble(),
      appliedBundles:
          (json['applied_bundles'] as List<dynamic>?)
              ?.where((e) => e != null && e is Map<String, dynamic>)
              .map(
                (e) => AppliedBundleModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      bundleSavings: (json['bundle_savings'] as num?)?.toDouble() ?? 0.0,
      subtotalAfterBundles: (json['subtotal_after_bundles'] as num?)
          ?.toDouble(),
      bundleHint: json['bundle_hint'],
      appliedPromotions:
          (json['available_promotions'] as List<dynamic>?)
              ?.where((e) => e != null && e is Map<String, dynamic>)
              .map((e) => PromotionApplied.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      validationIssues:
          (json['validation_issues'] as List<dynamic>?)
              ?.where((e) => e != null && e is Map<String, dynamic>)
              .map((e) => ValidationIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      locationStatus: json['location_status'] != null
          ? LocationStatus.fromJson(json['location_status'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'items': items.map((e) => e.toJson()).toList(),
      'total_items': totalItems,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'tip': tip,
      'delivery_fee': deliveryFee,
      'total': total,
      'applied_bundles': appliedBundles.map((e) => e.toJson()).toList(),
      'bundle_savings': bundleSavings,
      'subtotal_after_bundles': subtotalAfterBundles,
      'bundle_hint': bundleHint,
      'available_promotions': appliedPromotions.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PromotionApplied {
  final String id;
  final String name;
  final double amount;

  PromotionApplied({
    required this.id,
    required this.name,
    required this.amount,
  });

  factory PromotionApplied.fromJson(Map<String, dynamic> json) {
    return PromotionApplied(
      id: json['id'].toString(),
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'amount': amount};
  }
}

class SpotAvailability {
  final bool isAvailable;
  final String? message;

  SpotAvailability({required this.isAvailable, this.message});

  factory SpotAvailability.fromJson(Map<String, dynamic> json) {
    return SpotAvailability(
      isAvailable: json['is_available'],
      message: json['message'],
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
