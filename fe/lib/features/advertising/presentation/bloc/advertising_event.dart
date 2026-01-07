import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/advertising/domain/models/models.dart';

part 'advertising_event.freezed.dart';

/// Events for advertising BLoC.
@freezed
sealed class AdvertisingEvent with _$AdvertisingEvent {
  // AD SERVING EVENTS (Client App)
  
  /// Load featured ads for home carousel.
  const factory AdvertisingEvent.loadFeaturedAds({
    required double latitude,
    required double longitude,
    @Default(5) int limit,
  }) = LoadFeaturedAds;

  /// Load sponsored search results.
  const factory AdvertisingEvent.loadSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    @Default(3) int limit,
  }) = LoadSearchAds;

  /// Load map spotlight ads.
  const factory AdvertisingEvent.loadMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    @Default(5) int limit,
  }) = LoadMapAds;

  /// Track ad impression (fire and forget).
  const factory AdvertisingEvent.trackImpression({
    required int campaignId,
    required String placement,
    double? latitude,
    double? longitude,
  }) = TrackImpression;

  /// Track ad click (fire and forget).
  const factory AdvertisingEvent.trackClick({
    required int campaignId,
    required String placement,
    double? latitude,
    double? longitude,
  }) = TrackClick;

  // BUSINESS EVENTS (Business App)

  /// Load subscription plans.
  const factory AdvertisingEvent.loadPlans({
    String? regionCode,
  }) = LoadPlans;

  /// Load subscription for a bar.
  const factory AdvertisingEvent.loadSubscription({
    required int barId,
  }) = LoadSubscription;

  /// Create subscription.
  const factory AdvertisingEvent.createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  }) = CreateSubscription;

  /// Cancel subscription.
  const factory AdvertisingEvent.cancelSubscription({
    required int subscriptionId,
  }) = CancelSubscription;

  /// Load campaigns for a bar.
  const factory AdvertisingEvent.loadCampaigns({
    required int barId,
  }) = LoadCampaigns;

  /// Load campaign details.
  const factory AdvertisingEvent.loadCampaign({
    required int campaignId,
  }) = LoadCampaign;

  /// Create a new campaign.
  const factory AdvertisingEvent.createCampaign({
    required CreateCampaignRequest request,
  }) = CreateCampaignEvent;

  /// Pause a campaign.
  const factory AdvertisingEvent.pauseCampaign({
    required int campaignId,
  }) = PauseCampaign;

  /// Resume a campaign.
  const factory AdvertisingEvent.resumeCampaign({
    required int campaignId,
  }) = ResumeCampaign;

  /// Load campaign analytics.
  const factory AdvertisingEvent.loadAnalytics({
    required int campaignId,
  }) = LoadAnalytics;
}
