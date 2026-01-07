import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_ad.freezed.dart';
part 'search_ad.g.dart';

/// Sponsored search result model.
/// Returned from GET /advertising/serve/search
@freezed
class SearchAd with _$SearchAd {
  const factory SearchAd({
    @JsonKey(name: 'bar_id') required int barId,
    @JsonKey(name: 'bar_name') required String barName,
    @JsonKey(name: 'logo_url') String? logoUrl,
    required String tagline,
    required int position,
    @JsonKey(name: 'campaign_id') required int campaignId,
  }) = _SearchAd;

  factory SearchAd.fromJson(Map<String, dynamic> json) =>
      _$SearchAdFromJson(json);
}
