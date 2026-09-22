import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/error/exceptions.dart';
import 'package:barz/core/utils/idempotency.dart';
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
  Future<SubscriptionCaptureResult> capturePayment({
    required String paymentId,
    required int amountCents,
  });
  Future<SubscriptionUpgradeResult> upgradeSubscription({
    required int barId,
    required int amountCents,
    required String currency,
    required String country,
    required String cardToken,
    required ProrationInfo proration,
  });
  Future<List<AdCampaign>> getCampaigns(int barId);
  Future<AdCampaign> getCampaign(int campaignId);
  Future<AdCampaign> createCampaign(CreateCampaignRequest request);
  Future<AdCampaign> pauseCampaign(int campaignId, int barId);
  Future<AdCampaign> resumeCampaign(int campaignId, int barId);
  Future<void> deleteCampaign(int campaignId, int barId);
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
          'query': ?query,
          'category': ?category,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => SearchAd.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
          'zoom_level': ?zoomLevel,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => MapAd.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
          'placement': ?placement,
          'session_id': ?sessionId,
          'latitude': ?latitude,
          'longitude': ?longitude,
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
        queryParameters: {'region_code': ?regionCode},
      );
      return PlansResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
        queryParameters: {'bar_id': barId},
        data: {
          'tier': tier.name,
          'billing_cycle': 'monthly',
          'payment_method': {
            'type': 'pix',
          },
        },
      );

      // Backend returns two different response shapes:
      // 1. Credit Card (Immediate): Full AdSubscription with "active" status
      // 2. PIX (Waiting Payment): {status: "waiting_payment", pix_qr_code, ...}
      // Handle both gracefully
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'waiting_payment') {
        // PIX waiting payment - return basic AdSubscription with pending status
        return AdSubscription(
          id: 0,
          barId: barId,
          tier: tier,
          status: SubscriptionStatus.pending,
          currentPeriodStart: DateTime.now(),
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        );
      }

      return AdSubscription.fromJson(response.data);
    } on DioException catch (e) {
      // On web a blocked/refused request surfaces as Dio's generic
      // "The XMLHttpRequest onError callback was called" text, which
      // misleadingly points at CORS. Surface something actionable instead.
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException.connectionError(
          'Could not reach the server. Check your connection and try again.',
        );
      }
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<void> cancelSubscription(int subscriptionId) async {
    try {
      await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cancelSubscription(subscriptionId)}',
      );
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<SubscriptionCaptureResult> capturePayment({
    required String paymentId,
    required int amountCents,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.subscriptionCapture}',
        data: {
          'payment_id': paymentId,
          'amount_cents': amountCents,
        },
      );
      return SubscriptionCaptureResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException.fromResponse(
        e.response?.data as Map<String, dynamic>?,
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<SubscriptionUpgradeResult> upgradeSubscription({
    required int barId,
    required int amountCents,
    required String currency,
    required String country,
    required String cardToken,
    required ProrationInfo proration,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.subscriptionUpgrade}',
        data: {
          'order_id': 0,
          'bar_id': barId,
          'amount': amountCents,
          'currency': currency,
          'country': country,
          'payment_method': {
            'type': 'card',
            'token': cardToken,
            'provider': 'saved',
          },
          'proration_info': proration.toJson(),
        },
        options: Options(
          headers: {
            'X-Idempotency-Key': IdempotencyKey.generate(),
          },
        ),
      );
      return SubscriptionUpgradeResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException.fromResponse(
        e.response?.data as Map<String, dynamic>?,
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<AdCampaign> createCampaign(CreateCampaignRequest request) async {
    // `bar_id` is sent as a query parameter (per the documented contract) and
    // also kept in the body for compatibility with backends that still read it
    // from the payload.
    //
    // Budget and date keys are sent in BOTH spellings because the published
    // contract (`budget`, `start_time`, `end_time`) and the campaign response
    // model (`budget_amount`) disagree. FastAPI ignores unknown fields, so the
    // duplicate keys are harmless. Remove the duplicates once the backend
    // confirms the canonical payload — see docs/FE_BE_COMMUNICATION.md.
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaigns}',
        queryParameters: {'bar_id': request.barId},
        data: {
          'bar_id': request.barId,
          'name': request.name,
          'campaign_type': request.campaignType.wireName,
          'budget_type': request.budgetType.name,
          'budget': request.budgetAmount,
          'budget_amount': request.budgetAmount,
          'start_time': request.startDate.toIso8601String(),
          'start_date': request.startDate.toIso8601String(),
          if (request.endDate != null)
            'end_time': request.endDate!.toIso8601String(),
          if (request.endDate != null)
            'end_date': request.endDate!.toIso8601String(),
          if (request.targeting != null)
            'targeting': {
              if (request.targeting!.radiusKm != null)
                'radius_km': request.targeting!.radiusKm,
              if (request.targeting!.targetAudience != null)
                'target_audience': request.targeting!.targetAudience,
              if (request.targeting!.ageMin != null)
                'age_min': request.targeting!.ageMin,
              if (request.targeting!.ageMax != null)
                'age_max': request.targeting!.ageMax,
              if (request.targeting!.peakHoursOnly != null)
                'peak_hours_only': request.targeting!.peakHoursOnly,
              if (request.targeting!.budgetOptimizerEnabled != null)
                'budget_optimizer_enabled':
                    request.targeting!.budgetOptimizerEnabled,
            },
          if (request.creative != null)
            'creative': {
              if (request.creative!.title != null)
                'title': request.creative!.title,
              if (request.creative!.tagline != null)
                'tagline': request.creative!.tagline,
              if (request.creative!.cta != null) 'cta': request.creative!.cta,
              if (request.creative!.promoteHappyHour != null)
                'promote_happy_hour': request.creative!.promoteHappyHour,
              if (request.creative!.imageUrl != null)
                'image_url': request.creative!.imageUrl,
            },
          if (request.placementDistribution != null &&
              request.placementDistribution!.isNotEmpty)
            'placement_distribution': request.placementDistribution,
        },
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<AdCampaign> pauseCampaign(int campaignId, int barId) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.pauseCampaign(campaignId)}',
        queryParameters: {
          'bar_id': barId,
        }
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<AdCampaign> resumeCampaign(int campaignId, int barId) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.resumeCampaign(campaignId)}',
        queryParameters: {
          'bar_id': barId,
        }
      );
      return AdCampaign.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }

  @override
  Future<void> deleteCampaign(int campaignId, int barId) async {
    try {
      await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.campaign(campaignId)}',
        queryParameters: {
          'bar_id': barId,
        },
      );
    } on DioException catch (e) {
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
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
      throw ServerException.fromResponse(e.response?.data, e.response?.statusCode);
    }
  }
}
