import 'package:freezed_annotation/freezed_annotation.dart';

part 'featured_ad.freezed.dart';
part 'featured_ad.g.dart';

/// Featured ad model for home screen carousel.
/// Returned from GET /advertising/serve/featured
@freezed
class FeaturedAd with _$FeaturedAd {
  const factory FeaturedAd({
    @JsonKey(name: 'bar_id') required int barId,
    @JsonKey(name: 'bar_name') required String barName,
    @JsonKey(name: 'logo_url') String? logoUrl,
    required String tagline,
    @JsonKey(name: 'distance_km') required double distanceKm,
    @JsonKey(name: 'campaign_id') required int campaignId,
  }) = _FeaturedAd;

  factory FeaturedAd.fromJson(Map<String, dynamic> json) =>
      _$FeaturedAdFromJson(json);
}
