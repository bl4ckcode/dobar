import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/trending/domain/models/trending_drink.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';

abstract class HomeModel {
  UserStatus? get userStatus;
  bool get locationMismatch;
  List<NearbyBar> get nearbyBars;
  TrendingSection get trendingDrinks;
  List<PromotionModel> get activePromotions;
  String? get displayName;
  PromoSummary? get promoSummary;
  NearestVenue? get nearestVenue;

  factory HomeModel({
    UserStatus? userStatus,
    required bool locationMismatch,
    required List<NearbyBar> nearbyBars,
    required TrendingSection trendingDrinks,
    required List<PromotionModel> activePromotions,
    String? displayName,
    PromoSummary? promoSummary,
    NearestVenue? nearestVenue,
  }) = _HomeModelImpl;

  factory HomeModel.fromJson(Map<String, dynamic> json) =
      _HomeModelImpl.fromJson;
}

class _HomeModelImpl implements HomeModel {
  @override
  final UserStatus? userStatus;
  @override
  final bool locationMismatch;
  @override
  final List<NearbyBar> nearbyBars;
  @override
  final TrendingSection trendingDrinks;
  @override
  final List<PromotionModel> activePromotions;
  @override
  final String? displayName;
  @override
  final PromoSummary? promoSummary;
  @override
  final NearestVenue? nearestVenue;

  _HomeModelImpl({
    this.userStatus,
    required this.locationMismatch,
    required this.nearbyBars,
    required this.trendingDrinks,
    required this.activePromotions,
    this.displayName,
    this.promoSummary,
    this.nearestVenue,
  });

  factory _HomeModelImpl.fromJson(Map<String, dynamic> json) {
    return _HomeModelImpl(
      userStatus: json['user_status'] != null
          ? UserStatus.fromJson(json['user_status'])
          : null,
      locationMismatch: json['location_mismatch'] ?? false,
      nearbyBars:
          (json['nearby_bars'] as List?)
              ?.map((e) => NearbyBar.fromJson(e))
              .toList() ??
          [],
      trendingDrinks: json['trending_drinks'] != null
          ? TrendingSection.fromJson(json['trending_drinks'])
          : TrendingSection(mostWanted: [], hottest: []),
      activePromotions:
          (json['active_promotions'] as List?)
              ?.map((e) => PromotionModel.fromJson(e))
              .toList() ??
          [],
      displayName: (json['display_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['display_name'] as String).trim(),
      promoSummary: json['promo_summary'] is Map<String, dynamic>
          ? PromoSummary.fromJson(json['promo_summary'])
          : null,
      nearestVenue: json['nearest_venue'] is Map<String, dynamic>
          ? NearestVenue.fromJson(json['nearest_venue'])
          : null,
    );
  }
}

/// Server-computed count of promotions usable now. Absent => unknown.
class PromoSummary {
  final int total;
  const PromoSummary({required this.total});

  factory PromoSummary.fromJson(Map<String, dynamic> json) =>
      PromoSummary(total: (json['total'] as num?)?.toInt() ?? 0);
}

/// Nearest ready venue, independent of carousel ranking/limits.
class NearestVenue {
  final int id;
  final String name;
  final double? distanceMeters;
  const NearestVenue({
    required this.id,
    required this.name,
    this.distanceMeters,
  });

  factory NearestVenue.fromJson(Map<String, dynamic> json) => NearestVenue(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
  );

  BarModel toBarModel() => BarModel(
    id: id,
    name: name,
    address: '',
    phoneNumber: '',
    email: '',
    approximateLocation: distanceMeters,
  );
}

class UserStatus {
  final ActiveCart? activeCart;
  final int unreadNotifications;

  UserStatus({this.activeCart, required this.unreadNotifications});

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    return UserStatus(
      activeCart: json['active_cart'] != null
          ? ActiveCart.fromJson(json['active_cart'])
          : null,
      unreadNotifications: json['unread_notifications'] ?? 0,
    );
  }
}

class ActiveCart {
  final int itemCount;
  final double total;
  final int barId;
  final String barName;

  ActiveCart({
    required this.itemCount,
    required this.total,
    required this.barId,
    required this.barName,
  });

  factory ActiveCart.fromJson(Map<String, dynamic> json) {
    return ActiveCart(
      itemCount: json['item_count'] ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      barId: json['bar_id'] ?? 0,
      barName: json['bar_name'] ?? '',
    );
  }
}

class NearbyBar {
  final int id;
  final String name;
  final String? imageUrl;
  final double? distanceMeters;
  final double rating;
  final bool isOpen;
  final String? category;

  /// `happy_hour` | `cashback` | `promotion` (backend classification).
  final String? primaryPromotion;
  final String? promotionText;

  NearbyBar({
    required this.id,
    required this.name,
    this.imageUrl,
    this.distanceMeters,
    required this.rating,
    required this.isOpen,
    this.category,
    this.primaryPromotion,
    this.promotionText,
  });

  factory NearbyBar.fromJson(Map<String, dynamic> json) {
    return NearbyBar(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? false,
      category: json['category'] as String?,
      primaryPromotion: json['primary_promotion'] as String?,
      promotionText: json['promotion_text'] as String?,
    );
  }

  BarModel toBarModel() {
    return BarModel(
      id: id,
      name: name,
      imageUrl: imageUrl,
      address: '', // Placeholder
      phoneNumber: '', // Placeholder
      email: '', // Placeholder
      approximateLocation: distanceMeters,
    );
  }
}

class TrendingSection {
  final List<TrendingDrink> mostWanted;
  final List<TrendingDrink> hottest;

  TrendingSection({required this.mostWanted, required this.hottest});

  factory TrendingSection.fromJson(Map<String, dynamic> json) {
    return TrendingSection(
      mostWanted:
          (json['most_wanted'] as List?)
              ?.map((e) => TrendingDrink.fromJson(e))
              .toList() ??
          [],
      hottest:
          (json['hottest'] as List?)
              ?.map((e) => TrendingDrink.fromJson(e))
              .toList() ??
          [],
    );
  }
}
