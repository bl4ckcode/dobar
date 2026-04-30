import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:barz/features/advertising/domain/repositories/advertising_repository.dart';

/// Use cases for advertising operations.
/// Follows single responsibility - one class for all advertising business logic.
class AdvertisingUsecase {
  final AdvertisingRepository _repository;

  AdvertisingUsecase(this._repository);

  // ═══════════════════════════════════════════════════════════════════════════
  // AD SERVING (Client App)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get featured ads for home carousel.
  Future<List<FeaturedAd>> getFeaturedAds({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) {
    return _repository.getFeaturedAds(
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  /// Get sponsored search results.
  Future<List<SearchAd>> getSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    int limit = 3,
  }) {
    return _repository.getSearchAds(
      latitude: latitude,
      longitude: longitude,
      query: query,
      category: category,
      limit: limit,
    );
  }

  /// Get map spotlight ads.
  Future<List<MapAd>> getMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    int limit = 5,
  }) {
    return _repository.getMapAds(
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel,
      limit: limit,
    );
  }

  /// Track ad impression.
  Future<void> trackImpression({
    required int campaignId,
    required String placement,
    double? latitude,
    double? longitude,
  }) {
    return _repository.trackAdEvent(
      campaignId: campaignId,
      action: 'impression',
      placement: placement,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Track ad click.
  Future<void> trackClick({
    required int campaignId,
    required String placement,
    double? latitude,
    double? longitude,
  }) {
    return _repository.trackAdEvent(
      campaignId: campaignId,
      action: 'click',
      placement: placement,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Track conversion.
  Future<void> trackConversion({
    required int campaignId,
    required String placement,
    double? latitude,
    double? longitude,
  }) {
    return _repository.trackAdEvent(
      campaignId: campaignId,
      action: 'conversion',
      placement: placement,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Get available subscription plans.
  Future<PlansResponse> getPlans({String? regionCode}) {
    return _repository.getPlans(regionCode: regionCode);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMPAIGN MANAGEMENT (Business App)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get subscription for a bar.
  Future<AdSubscription?> getSubscription(int barId) {
    return _repository.getSubscription(barId);
  }

  /// Create subscription.
  Future<AdSubscription> createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  }) {
    return _repository.createSubscription(
      barId: barId,
      tier: tier,
      regionCode: regionCode,
    );
  }

  Future<SubscriptionTrialSetupResult> setupSubscriptionTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String customerEmail,
    required String customerName,
  }) {
    return _repository.setupSubscriptionTrial(
      barId: barId,
      ownerId: ownerId,
      plan: plan,
      paymentMethodId: paymentMethodId,
      customerEmail: customerEmail,
      customerName: customerName,
    );
  }

  /// Cancel subscription.
  Future<void> cancelSubscription(int subscriptionId) {
    return _repository.cancelSubscription(subscriptionId);
  }

  /// Capture payment after trial.
  Future<SubscriptionCaptureResult> capturePayment({
    required String paymentId,
    required int amountCents,
  }) {
    return _repository.capturePayment(
      paymentId: paymentId,
      amountCents: amountCents,
    );
  }

  /// Upgrade subscription with proration.
  Future<SubscriptionUpgradeResult> upgradeSubscription({
    required int barId,
    required int amountCents,
    required String currency,
    required String country,
    required String cardToken,
    required ProrationInfo proration,
  }) {
    return _repository.upgradeSubscription(
      barId: barId,
      amountCents: amountCents,
      currency: currency,
      country: country,
      cardToken: cardToken,
      proration: proration,
    );
  }

  /// List campaigns for a bar.
  Future<List<AdCampaign>> getCampaigns(int barId) {
    return _repository.getCampaigns(barId);
  }

  /// Get a specific campaign.
  Future<AdCampaign> getCampaign(int campaignId) {
    return _repository.getCampaign(campaignId);
  }

  /// Create a new campaign.
  Future<AdCampaign> createCampaign(CreateCampaignRequest request) {
    return _repository.createCampaign(request);
  }

  /// Pause a campaign.
  Future<AdCampaign> pauseCampaign(int campaignId) {
    return _repository.pauseCampaign(campaignId);
  }

  /// Resume a campaign.
  Future<AdCampaign> resumeCampaign(int campaignId) {
    return _repository.resumeCampaign(campaignId);
  }

  /// Get campaign analytics.
  Future<CampaignAnalytics> getCampaignAnalytics({
    required int campaignId,
    required int barId,
  }) {
    return _repository.getCampaignAnalytics(
      campaignId: campaignId,
      barId: barId,
    );
  }
}
