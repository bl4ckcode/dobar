import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/dio_network.dart';

/// Placement types for ad tracking.
enum AdPlacement {
  home('home'),
  search('search'),
  map('map'),
  promo('promo'),
  trending('trending'),  // For "Most Desired Drinks" section
  category('category'),  // For category-specific pages
  unknown('unknown');

  final String value;
  const AdPlacement(this.value);
}

/// Action types for ad tracking.
enum AdAction {
  impression('impression'),
  click('click'),
  conversion('conversion');

  final String value;
  const AdAction(this.value);
}

/// Service for tracking ad impressions, clicks, and conversions.
/// 
/// Usage:
/// ```dart
/// final tracker = AdTrackingService(dio);
/// await tracker.trackImpression(campaignId, AdPlacement.home);
/// await tracker.trackClick(campaignId, AdPlacement.home);
/// ```
/// 
/// Best practices:
/// - Track impressions when ad becomes visible (use VisibilityDetector)
/// - Track clicks before navigation (don't wait for response)
/// - Fire tracking calls in background, don't block UX
/// - Deduplicate: track impression once per session per ad
class AdTrackingService {
  final Dio _dio;
  final Set<String> _trackedImpressions = {};

  AdTrackingService({Dio? dio}) : _dio = dio ?? DioNetwork.appAPI;

  /// Track an ad impression (when ad becomes visible).
  /// Deduplicates by campaignId + placement per session.
  Future<void> trackImpression(
    int campaignId,
    AdPlacement placement, {
    double? latitude,
    double? longitude,
  }) async {
    final key = '${campaignId}_${placement.value}_impression';
    if (_trackedImpressions.contains(key)) {
      debugPrint('[AdTracking] Skipping duplicate impression: $key');
      return;
    }
    _trackedImpressions.add(key);
    await _track(campaignId, AdAction.impression, placement, latitude, longitude);
  }

  /// Track an ad click.
  Future<void> trackClick(
    int campaignId,
    AdPlacement placement, {
    double? latitude,
    double? longitude,
  }) async {
    await _track(campaignId, AdAction.click, placement, latitude, longitude);
  }

  /// Track a conversion (e.g., user visited bar, made order).
  Future<void> trackConversion(
    int campaignId,
    AdPlacement placement, {
    double? latitude,
    double? longitude,
  }) async {
    await _track(campaignId, AdAction.conversion, placement, latitude, longitude);
  }

  Future<void> _track(
    int campaignId,
    AdAction action,
    AdPlacement placement,
    double? latitude,
    double? longitude,
  ) async {
    try {
      await _dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.adTrack}',
        data: {
          'campaign_id': campaignId,
          'action': action.value,
          'placement': placement.value,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      debugPrint('[AdTracking] Tracked ${action.value} for campaign $campaignId');
    } catch (e) {
      // Silent fail - don't block UX for tracking
      debugPrint('[AdTracking] Failed to track: $e');
    }
  }

  /// Clear tracked impressions (e.g., on new session).
  void clearSession() {
    _trackedImpressions.clear();
  }
}
