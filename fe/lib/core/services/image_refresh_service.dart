import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';

/// Service to handle presigned S3 URL expiration and refresh
class ImageRefreshService {
  final Dio _dio;

  // Cache of refreshed URLs: barId -> (imageUrl, expirationTimestamp)
  final Map<int, ({String url, int expiration})> _urlCache = {};

  // Track bars currently being refreshed (deduplication)
  final Set<int> _pendingRefreshes = {};

  // Track failed refreshes with cooldown: barId -> failedTimestamp
  final Map<int, int> _failedRefreshes = {};

  // Buffer time before expiration to preemptively refresh (5 minutes)
  static const int _expirationBufferSeconds = 5 * 60;

  // Cooldown period after a failed refresh (30 seconds)
  static const int _failureCooldownSeconds = 30;

  ImageRefreshService(this._dio);

  /// Checks if an image URL needs refreshing based on expiration timestamp
  /// Returns true if the URL is expired or about to expire
  bool isExpired(int? expirationTimestamp) {
    if (expirationTimestamp == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= (expirationTimestamp - _expirationBufferSeconds);
  }

  /// Gets a valid image URL for a bar, refreshing if necessary
  ///
  /// [barId] - The bar's ID
  /// [currentUrl] - The current image URL
  /// [expirationTimestamp] - Unix timestamp when the URL expires
  ///
  /// Returns the valid URL (either current or refreshed)
  Future<String?> getValidImageUrl({
    required int barId,
    required String? currentUrl,
    required int? expirationTimestamp,
  }) async {
    // No URL to validate
    if (currentUrl == null || currentUrl.isEmpty) {
      return null;
    }

    // Check cache first
    final cached = _urlCache[barId];
    if (cached != null && !isExpired(cached.expiration)) {
      return cached.url;
    }

    // If not expired, use current URL
    if (!isExpired(expirationTimestamp)) {
      // Cache it for future checks
      if (expirationTimestamp != null) {
        _urlCache[barId] = (url: currentUrl, expiration: expirationTimestamp);
      }
      return currentUrl;
    }

    // URL is expired, refresh it
    try {
      final refreshedUrl = await _refreshBarImageUrl(barId);
      return refreshedUrl ??
          currentUrl; // Fall back to current if refresh fails
    } catch (e) {
      // If refresh fails, still return current URL (might work, might not)
      return currentUrl;
    }
  }

  /// Refreshes the image URL for a bar
  Future<String?> _refreshBarImageUrl(int barId) async {
    try {
      final response = await _dio.get(ApiEndpoints.refreshBarImage(barId));

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final newUrl = data['image_url'] as String?;
        final newExpiration = data['image_url_expiration'] as int?;

        if (newUrl != null && newExpiration != null) {
          _urlCache[barId] = (url: newUrl, expiration: newExpiration);
          return newUrl;
        }
      }
      return null;
    } on DioException catch (e) {
      // Log but don't throw - let caller handle with fallback
      // ignore: avoid_print
      print('Failed to refresh image URL for bar $barId: ${e.message}');
      // Mark as failed with cooldown
      _failedRefreshes[barId] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return null;
    } finally {
      _pendingRefreshes.remove(barId);
    }
  }

  /// Force refresh an image URL (useful when user pulls to refresh)
  /// Returns null if already refreshing, recently failed, or refresh fails
  Future<String?> forceRefresh(int barId) async {
    // Deduplication: Don't refresh if already in progress
    if (_pendingRefreshes.contains(barId)) {
      return null;
    }

    // Cooldown: Don't refresh if recently failed
    final failedAt = _failedRefreshes[barId];
    if (failedAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - failedAt < _failureCooldownSeconds) {
        return null; // Still in cooldown
      }
      // Cooldown expired, remove from failed set
      _failedRefreshes.remove(barId);
    }

    _pendingRefreshes.add(barId);
    _urlCache.remove(barId);
    return _refreshBarImageUrl(barId);
  }

  /// Check if a bar is in cooldown after a failed refresh
  bool isInCooldown(int barId) {
    final failedAt = _failedRefreshes[barId];
    if (failedAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now - failedAt < _failureCooldownSeconds;
  }

  /// Clear the URL cache
  void clearCache() {
    _urlCache.clear();
  }

  /// Clear a specific bar's cached URL
  void clearBarCache(int barId) {
    _urlCache.remove(barId);
  }
}
