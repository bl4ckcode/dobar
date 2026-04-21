import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/advertising/domain/models/models.dart';
import 'package:dio/dio.dart';

abstract class AdvertisingDatasource {
  // Public endpoints
  Future<List<FeaturedAd>> getFeaturedAds({
    required double latitude,
    required double longitude,
    int limit = 5,
  });

  Future<List<SearchAd>> getSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    int limit = 3,
  });

  Future<List<MapAd>> getMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    int limit = 5,
  });

  Future<void> trackAdEvent({
    required int campaignId,
    required String action,
    String? placement,
    String? sessionId,
    double? latitude,
    double? longitude,
  });

  Future<PlansResponse> getPlans({String? regionCode});

  // Authenticated endpoints
  Future<AdSubscription?> getSubscription(int barId);
  Future<AdSubscription> createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  });
  Future<SubscriptionTrialSetupResult> setupSubscriptionTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String customerEmail,
    required String customerName,
  });
  Future<void> cancelSubscription(int subscriptionId);
  Future<List<AdCampaign>> getCampaigns(int barId);
  Future<AdCampaign> getCampaign(int campaignId);
  Future<AdCampaign> createCampaign(CreateCampaignRequest request);
  Future<AdCampaign> pauseCampaign(int campaignId);
  Future<AdCampaign> resumeCampaign(int campaignId);
  Future<CampaignAnalytics> getCampaignAnalytics({
    required int campaignId,
    required int barId,
  });
}

class AdvertisingNetworkDatasource implements AdvertisingDatasource {
  final Dio dio;

  AdvertisingNetworkDatasource({required this.dio});

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<FeaturedAd>> getFeaturedAds({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adServeFeatured}',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => FeaturedAd.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get featured ads',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<SearchAd>> getSearchAds({
    required double latitude,
    required double longitude,
    String? query,
    String? category,
    int limit = 3,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adServeSearch}',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          if (query != null) 'query': query,
          if (category != null) 'category': category,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => SearchAd.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get search ads',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<MapAd>> getMapAds({
    required double latitude,
    required double longitude,
    int? zoomLevel,
    int limit = 5,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adServeMap}',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          if (zoomLevel != null) 'zoom_level': zoomLevel,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => MapAd.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get map ads',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> trackAdEvent({
    required int campaignId,
    required String action,
    String? placement,
    String? sessionId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adTrack}',
        data: {
          'campaign_id': campaignId,
          'action': action,
          if (placement != null) 'placement': placement,
          if (sessionId != null) 'session_id': sessionId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
    } on DioException {
      // Silent fail for tracking - don't block UX
    }
  }

  @override
  Future<PlansResponse> getPlans({String? regionCode}) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adPlans}',
        queryParameters: {if (regionCode != null) 'region_code': regionCode},
      );
      return PlansResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get plans',
        e.response?.statusCode,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATED ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<AdSubscription?> getSubscription(int barId) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.subscription(barId)}',
      );
      return AdSubscription.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No subscription
      }
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get subscription',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<AdSubscription> createSubscription({
    required int barId,
    required SubscriptionTier tier,
    required String regionCode,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.subscriptions}',
        data: {'bar_id': barId, 'tier': tier.name, 'region_code': regionCode},
      );
      return AdSubscription.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to create subscription',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<SubscriptionTrialSetupResult> setupSubscriptionTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.subscriptionTrialSetup}',
        data: {
          'bar_id': barId,
          'owner_id': ownerId,
          'plan': plan,
          'trial_days': 7,
          'payment_method_id': paymentMethodId,
          'customer_email': customerEmail,
          'customer_name': customerName,
          'metadata': <String, dynamic>{},
        },
      );
      return SubscriptionTrialSetupResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ??
            e.response?.data?['error']?['message'] ??
            'Failed to setup trial',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> cancelSubscription(int subscriptionId) async {
    try {
      await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cancelSubscription(subscriptionId)}',
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to cancel subscription',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<AdCampaign>> getCampaigns(int barId) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaigns}',
        queryParameters: {'bar_id': barId},
      );
      final campaignsList = response.data['campaigns'] as List? ?? [];
      return campaignsList.map((json) => AdCampaign.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get campaigns',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<AdCampaign> getCampaign(int campaignId) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaign(campaignId)}',
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get campaign',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<AdCampaign> createCampaign(CreateCampaignRequest request) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaigns}',
        data: {
          'bar_id': request.barId,
          'name': request.name,
          'campaign_type': request.campaignType.name,
          'budget_type': request.budgetType.name,
          'budget_amount': request.budgetAmount,
          'start_date': request.startDate.toIso8601String(),
          if (request.endDate != null)
            'end_date': request.endDate!.toIso8601String(),
          if (request.targeting != null)
            'targeting': {
              if (request.targeting!.radiusKm != null)
                'radius_km': request.targeting!.radiusKm,
              if (request.targeting!.targetAudience != null)
                'target_audience': request.targeting!.targetAudience,
            },
          if (request.creative != null)
            'creative': {
              if (request.creative!.tagline != null)
                'tagline': request.creative!.tagline,
              if (request.creative!.imageUrl != null)
                'image_url': request.creative!.imageUrl,
            },
        },
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to create campaign',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<AdCampaign> pauseCampaign(int campaignId) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.pauseCampaign(campaignId)}',
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to pause campaign',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<AdCampaign> resumeCampaign(int campaignId) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.resumeCampaign(campaignId)}',
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to resume campaign',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<CampaignAnalytics> getCampaignAnalytics({
    required int campaignId,
    required int barId,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaignAnalytics(campaignId)}',
        queryParameters: {'bar_id': barId},
      );
      return CampaignAnalytics.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get campaign analytics',
        e.response?.statusCode,
      );
    }
  }
}
