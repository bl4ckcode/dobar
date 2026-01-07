import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_ad.freezed.dart';
part 'map_ad.g.dart';

/// Map spotlight ad model for highlighted pins on map.
/// Returned from GET /advertising/serve/map
@freezed
abstract class MapAd with _$MapAd {
  const factory MapAd({
    @JsonKey(name: 'bar_id') required int barId,
    @JsonKey(name: 'bar_name') required String barName,
    required double latitude,
    required double longitude,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'campaign_id') required int campaignId,
  }) = _MapAd;

  factory MapAd.fromJson(Map<String, dynamic> json) =>
      _$MapAdFromJson(json);
}
