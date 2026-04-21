import 'package:barz/features/advertising/data/datasources/advertising_datasource.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:barz/features/advertising/domain/repositories/advertising_repository.dart';

class AdvertisingRepositoryImpl implements AdvertisingRepository {
  final AdvertisingDatasource _datasource;

  AdvertisingRepositoryImpl(this._datasource);

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<FeaturedAd>> getFeaturedAds({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) {
    return _datasource.getFeaturedAds(
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  @override
  Future<List<SearchAd>> getSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    int limit = 3,
  }) {
    return _datasource.getSearchAds(
      latitude: latitude,
      longitude: longitude,
      query: query,
      category: category,
      limit: limit,
    );
  }

  @override
  Future<List<MapAd>> getMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    int limit = 5,
  }) {
    return _datasource.getMapAds(
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel,
      limit: limit,
    );
  }

  @override
  Future<void> trackAdEvent({
    required int campaignId,
    required String action,
    String? placement,
    String? sessionId,
    double? latitude,
    double? longitude,
  }) {
    return _datasource.trackAdEvent(
      campaignId: campaignId,
      action: action,
      placement: placement,
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<PlansResponse> getPlans({String? regionCode}) {
    return _datasource.getPlans(regionCode: regionCode);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATED ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<AdSubscription?> getSubscription(int barId) {
    return _datasource.getSubscription(barId);
  }

  @override
  Future<AdSubscription> createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  }) {
    return _datasource.createSubscription(
      barId: barId,
      tier: tier,
      regionCode: regionCode,
    );
  }

  @override
  Future<SubscriptionTrialSetupResult> setupSubscriptionTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String customerEmail,
    required String customerName,
  }) {
    return _datasource.setupSubscriptionTrial(
      barId: barId,
      ownerId: ownerId,
      plan: plan,
      paymentMethodId: paymentMethodId,
      customerEmail: customerEmail,
      customerName: customerName,
    );
  }

  @override
  Future<void> cancelSubscription(int subscriptionId) {
    return _datasource.cancelSubscription(subscriptionId);
  }

  @override
  Future<List<AdCampaign>> getCampaigns(int barId) {
    return _datasource.getCampaigns(barId);
  }

  @override
  Future<AdCampaign> getCampaign(int campaignId) {
    return _datasource.getCampaign(campaignId);
  }

  @override
  Future<AdCampaign> createCampaign(CreateCampaignRequest request) {
    return _datasource.createCampaign(request);
  }

  @override
  Future<AdCampaign> pauseCampaign(int campaignId) {
    return _datasource.pauseCampaign(campaignId);
  }

  @override
  Future<AdCampaign> resumeCampaign(int campaignId) {
    return _datasource.resumeCampaign(campaignId);
  }

  @override
  Future<CampaignAnalytics> getCampaignAnalytics({
    required int campaignId,
    required int barId,
  }) {
    return _datasource.getCampaignAnalytics(
      campaignId: campaignId,
      barId: barId,
    );
  }
}
