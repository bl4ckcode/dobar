enum OfferType { discount, cashback, freeItem, buyOneGetOne, happyHour }

enum DiscountType { percentage, fixedAmount }

class OfferModel {
  final int id;
  final int partnerId;
  final String title;
  final String? description;
  final OfferType type;
  final DiscountType? discountType;
  final double? discountValue;
  final double? minOrderValue;
  final double? maxDiscount;
  final int? freeItemId;
  final String? freeItemName;
  final String? imageUrl;
  final String? termsAndConditions;
  final DateTime startDate;
  final DateTime endDate;
  final List<int>? applicableDays;
  final String? startTime;
  final String? endTime;
  final int? usageLimit;
  final int usageCount;
  final bool isActive;
  final bool isPremiumOnly;
  final DateTime createdAt;

  OfferModel({
    required this.id,
    required this.partnerId,
    required this.title,
    this.description,
    required this.type,
    this.discountType,
    this.discountValue,
    this.minOrderValue,
    this.maxDiscount,
    this.freeItemId,
    this.freeItemName,
    this.imageUrl,
    this.termsAndConditions,
    required this.startDate,
    required this.endDate,
    this.applicableDays,
    this.startTime,
    this.endTime,
    this.usageLimit,
    this.usageCount = 0,
    this.isActive = true,
    this.isPremiumOnly = false,
    required this.createdAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'],
      partnerId: json['partner_id'],
      title: json['title'],
      description: json['description'],
      type: OfferType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OfferType.discount,
      ),
      discountType: json['discount_type'] != null
          ? DiscountType.values.firstWhere(
              (e) => e.name == json['discount_type'],
              orElse: () => DiscountType.percentage,
            )
          : null,
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      minOrderValue: (json['min_order_value'] as num?)?.toDouble(),
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      freeItemId: json['free_item_id'],
      freeItemName: json['free_item_name'],
      imageUrl: json['image_url'],
      termsAndConditions: json['terms_and_conditions'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      applicableDays: (json['applicable_days'] as List<dynamic>?)?.cast<int>(),
      startTime: json['start_time'],
      endTime: json['end_time'],
      usageLimit: json['usage_limit'],
      usageCount: json['usage_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      isPremiumOnly: json['is_premium_only'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partner_id': partnerId,
      'title': title,
      'description': description,
      'type': type.name,
      'discount_type': discountType?.name,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'max_discount': maxDiscount,
      'free_item_id': freeItemId,
      'free_item_name': freeItemName,
      'image_url': imageUrl,
      'terms_and_conditions': termsAndConditions,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'applicable_days': applicableDays,
      'start_time': startTime,
      'end_time': endTime,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'is_active': isActive,
      'is_premium_only': isPremiumOnly,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get hasAvailableUsage => usageLimit == null || usageCount < usageLimit!;

  String get displayDiscount {
    if (discountType == DiscountType.percentage) {
      return '${discountValue?.toInt()}% OFF';
    }
    return 'R\$ ${discountValue?.toStringAsFixed(2)} OFF';
  }
}
