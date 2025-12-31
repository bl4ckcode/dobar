import 'location_model.dart';

class PartnerProximity {
  final int partnerId;
  final String partnerName;
  final String? partnerImageUrl;
  final LocationModel partnerLocation;
  final double distanceInMeters;
  final bool isWithinRange;
  final List<ProximityOffer> availableOffers;

  PartnerProximity({
    required this.partnerId,
    required this.partnerName,
    this.partnerImageUrl,
    required this.partnerLocation,
    required this.distanceInMeters,
    required this.isWithinRange,
    this.availableOffers = const [],
  });

  factory PartnerProximity.fromJson(Map<String, dynamic> json) {
    return PartnerProximity(
      partnerId: json['partner_id'],
      partnerName: json['partner_name'],
      partnerImageUrl: json['partner_image_url'],
      partnerLocation: LocationModel.fromJson(json['partner_location']),
      distanceInMeters: (json['distance_in_meters'] as num).toDouble(),
      isWithinRange: json['is_within_range'] ?? false,
      availableOffers: (json['available_offers'] as List<dynamic>?)
              ?.map((e) => ProximityOffer.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner_id': partnerId,
      'partner_name': partnerName,
      'partner_image_url': partnerImageUrl,
      'partner_location': partnerLocation.toJson(),
      'distance_in_meters': distanceInMeters,
      'is_within_range': isWithinRange,
      'available_offers': availableOffers.map((e) => e.toJson()).toList(),
    };
  }
}

class ProximityOffer {
  final int id;
  final String title;
  final String? description;
  final double discountPercentage;
  final DateTime expiresAt;

  ProximityOffer({
    required this.id,
    required this.title,
    this.description,
    required this.discountPercentage,
    required this.expiresAt,
  });

  factory ProximityOffer.fromJson(Map<String, dynamic> json) {
    return ProximityOffer(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      discountPercentage: (json['discount_percentage'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discount_percentage': discountPercentage,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
