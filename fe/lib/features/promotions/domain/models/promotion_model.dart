enum DiscountType { percentage, fixed, bogo }

class PromotionModel {
  final int id;
  final int barId;
  final String title;
  final String? description;
  final DiscountType discountType;
  final double discountValue;
  final String? startTime;
  final String? endTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool recurring;
  final List<String> recurringDays;
  final String? terms;
  final bool isActive;
  final String? imageUrl;
  final int? imageUrlExpiration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // For nearby endpoint - includes bar info
  final String? barName;
  final String? barAddress;
  final double? approximateLocation;

  PromotionModel({
    required this.id,
    required this.barId,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.recurring = false,
    this.recurringDays = const [],
    this.terms,
    this.isActive = true,
    this.imageUrl,
    this.imageUrlExpiration,
    this.createdAt,
    this.updatedAt,
    this.barName,
    this.barAddress,
    this.approximateLocation,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'],
      barId: json['bar_id'],
      title: json['title'],
      description: json['description'],
      discountType: DiscountType.values.firstWhere(
          (e) => e.name == json['discount_type'],
          orElse: () => DiscountType.percentage),
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      startTime: json['start_time'],
      endTime: json['end_time'],
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      recurring: json['recurring'] ?? false,
      recurringDays: (json['recurring_days'] as List<dynamic>?)?.cast<String>() ?? [],
      terms: json['terms'],
      isActive: json['is_active'] ?? true,
      imageUrl: json['image_url'],
      imageUrlExpiration: json['image_url_expiration'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      // PromotionWithBar fields (from /nearby endpoint)
      barName: json['bar_name'],
      barAddress: json['bar_address'],
      approximateLocation: (json['approximate_location'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bar_id': barId,
      'title': title,
      'description': description,
      'discount_type': discountType.name,
      'discount_value': discountValue,
      'start_time': startTime,
      'end_time': endTime,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'recurring': recurring,
      'recurring_days': recurringDays,
      'terms': terms,
      'is_active': isActive,
      'image_url': imageUrl,
    };
  }

  /// Formatted discount string for display
  String get discountText {
    switch (discountType) {
      case DiscountType.percentage:
        return '${discountValue.toInt()}% OFF';
      case DiscountType.fixed:
        return 'R\$${discountValue.toStringAsFixed(0)} OFF';
      case DiscountType.bogo:
        return 'COMPRE 1 LEVE 2';
    }
  }

  /// Time range for display (e.g., "17:00 - 20:00")
  String? get timeRange {
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return null;
  }

  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}
