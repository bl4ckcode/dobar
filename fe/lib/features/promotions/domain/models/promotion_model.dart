enum PromotionType { banner, featured, drink, partner, cashback, premium }

class PromotionModel {
  final int id;
  final PromotionType type;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? actionUrl;
  final int? partnerId;
  final int? offerId;
  final int? drinkId;
  final double? cashbackPercentage;
  final int priority;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  PromotionModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.actionUrl,
    this.partnerId,
    this.offerId,
    this.drinkId,
    this.cashbackPercentage,
    this.priority = 0,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'],
      type: PromotionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PromotionType.banner),
      title: json['title'],
      subtitle: json['subtitle'],
      description: json['description'],
      imageUrl: json['image_url'],
      actionUrl: json['action_url'],
      partnerId: json['partner_id'],
      offerId: json['offer_id'],
      drinkId: json['drink_id'],
      cashbackPercentage: (json['cashback_percentage'] as num?)?.toDouble(),
      priority: json['priority'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'image_url': imageUrl,
      'action_url': actionUrl,
      'partner_id': partnerId,
      'offer_id': offerId,
      'drink_id': drinkId,
      'cashback_percentage': cashbackPercentage,
      'priority': priority,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }
}
