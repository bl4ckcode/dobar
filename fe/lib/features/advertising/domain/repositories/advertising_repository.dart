import 'package:barz/features/advertising/domain/models/models.dart';

/// Abstract repository for advertising operations.
/// Separated into public (ad serving) and authenticated (business) operations.
abstract class AdvertisingRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC ENDPOINTS - Ad Serving (no auth required)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get featured ads for home carousel.
  Future<List<FeaturedAd>> getFeaturedAds({
    required double latitude,
    required double longitude,
    int limit = 5,
  });

  /// Get sponsored search results.
  Future<List<SearchAd>> getSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    int limit = 3,
  });

  /// Get map spotlight ads.
  Future<List<MapAd>> getMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    int limit = 5,
  });

  /// Track ad impression, click, or conversion.
  Future<void> trackAdEvent({
    required int campaignId,
    required String action, // 'impression', 'click', 'conversion'
    String? placement,
    String? sessionId,
    double? latitude,
    double? longitude,
  });

  /// Get available subscription plans (public, with regional pricing).
  Future<PlansResponse> getPlans({String? regionCode});

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATED ENDPOINTS - Business Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get subscription for a bar.
  Future<AdSubscription?> getSubscription(int barId);

  /// Create a subscription for a bar.
  Future<AdSubscription> createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  });

  /// Cancel a subscription.
  Future<void> cancelSubscription(int subscriptionId);

  /// List campaigns for a bar.
  Future<List<AdCampaign>> getCampaigns(int barId);

  /// Get a specific campaign.
  Future<AdCampaign> getCampaign(int campaignId);

  /// Create a new campaign.
  Future<AdCampaign> createCampaign(CreateCampaignRequest request);

  /// Pause a campaign.
  Future<AdCampaign> pauseCampaign(int campaignId);

  /// Resume a campaign.
  Future<AdCampaign> resumeCampaign(int campaignId);

  /// Get campaign analytics.
  Future<CampaignAnalytics> getCampaignAnalytics({
    required int campaignId,
    required int barId,
  });
}
