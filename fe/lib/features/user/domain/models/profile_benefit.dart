/// Authenticated owned benefit from `GET /me/benefits` (C04-AC07).
/// Amounts for [BenefitUnit.brlCents] are integer cents; no fixture data.
enum BenefitKind { proCoupon, cashback }

enum BenefitUnit { coupon, brlCents }

class ProfileBenefit {
  const ProfileBenefit({
    required this.id,
    required this.kind,
    required this.active,
    required this.unit,
    required this.remaining,
    required this.conditions,
    required this.venueFilterSupported,
    this.unavailableReason,
    this.limit,
    this.pending,
    this.expiresAt,
    this.venueCount,
  });

  final String id;
  final BenefitKind kind;
  final bool active;
  final String? unavailableReason;
  final BenefitUnit unit;
  final int remaining;
  final int? limit;
  final int? pending;
  final DateTime? expiresAt;
  final List<String> conditions;
  final bool venueFilterSupported;
  final int? venueCount;

  /// Only active benefits with an authoritative venue rule may open venues.
  bool get canOpenVenues => active && venueFilterSupported;

  factory ProfileBenefit.fromJson(Map<String, dynamic> json) {
    final quantity = Map<String, dynamic>.from(json['quantity'] as Map);
    final eligibility = Map<String, dynamic>.from(json['eligibility'] as Map);
    return ProfileBenefit(
      id: json['id'] as String,
      kind: json['kind'] == 'cashback'
          ? BenefitKind.cashback
          : BenefitKind.proCoupon,
      active: json['status'] == 'active',
      unavailableReason: json['unavailable_reason'] as String?,
      unit: quantity['unit'] == 'brl_cents'
          ? BenefitUnit.brlCents
          : BenefitUnit.coupon,
      remaining: (quantity['remaining'] as num).toInt(),
      limit: (quantity['limit'] as num?)?.toInt(),
      pending: (quantity['pending'] as num?)?.toInt(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      conditions: [
        for (final c in (json['conditions'] as List? ?? const [])) c as String,
      ],
      venueFilterSupported: eligibility['venue_filter_supported'] == true,
      venueCount: (eligibility['venue_count'] as num?)?.toInt(),
    );
  }
}

class ProfileBenefits {
  const ProfileBenefits({required this.benefits, required this.activeCount});
  final List<ProfileBenefit> benefits;
  final int activeCount;

  factory ProfileBenefits.fromJson(Map<String, dynamic> json) => ProfileBenefits(
    benefits: [
      for (final b in (json['benefits'] as List? ?? const []))
        ProfileBenefit.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
  );
}

class BenefitPromotion {
  const BenefitPromotion({
    required this.id,
    required this.title,
    this.benefitText,
    this.terms,
    this.startTime,
    this.endTime,
    this.endsAt,
  });
  final int id;
  final String title;
  final String? benefitText;
  final String? terms;
  final String? startTime;
  final String? endTime;
  final DateTime? endsAt;

  factory BenefitPromotion.fromJson(Map<String, dynamic> json) =>
      BenefitPromotion(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        benefitText: json['benefit_text'] as String?,
        terms: json['terms'] as String?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.parse(json['ends_at'] as String),
      );
}

class BenefitVenue {
  const BenefitVenue({
    required this.barId,
    required this.promotions,
    this.name,
    this.address,
    this.category,
  });
  final int barId;
  final String? name;
  final String? address;
  final String? category;
  final List<BenefitPromotion> promotions;

  factory BenefitVenue.fromJson(Map<String, dynamic> json) => BenefitVenue(
    barId: (json['bar_id'] as num).toInt(),
    name: json['name'] as String?,
    address: json['address'] as String?,
    category: json['category'] as String?,
    promotions: [
      for (final p in (json['promotions'] as List? ?? const []))
        BenefitPromotion.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
  );
}

class BenefitVenues {
  const BenefitVenues({
    required this.benefitId,
    required this.conditions,
    required this.venues,
    required this.total,
  });
  final String benefitId;
  final List<String> conditions;
  final List<BenefitVenue> venues;
  final int total;

  factory BenefitVenues.fromJson(Map<String, dynamic> json) => BenefitVenues(
    benefitId: json['benefit_id'] as String,
    conditions: [
      for (final c in (json['conditions'] as List? ?? const [])) c as String,
    ],
    venues: [
      for (final v in (json['venues'] as List? ?? const []))
        BenefitVenue.fromJson(Map<String, dynamic>.from(v as Map)),
    ],
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}
