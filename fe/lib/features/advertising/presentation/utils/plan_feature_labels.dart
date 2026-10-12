import 'package:barz/l10n/app_localizations.dart';

/// Resolves the plan feature keys returned by `GET /advertising/plans`.
///
/// The backend returns opaque string keys inside each plan's `features` array
/// (for example `"feature_basic_listing"`). The backend is free to add new keys
/// at any time, so this resolver must **never** leak a raw key into the UI:
/// any key without a mapping falls back to a humanized version of itself.
extension PlanFeatureL10n on AppLocalizations {
  /// Localized, user-facing description for a backend plan feature key.
  String planFeatureLabel(String key) {
    return switch (key) {
      'feature_basic_listing' => feature_basic_listing,
      'feature_order_management' => feature_order_management,
      'feature_basic_analytics' => feature_basic_analytics,
      'feature_everything_regular' => feature_everything_regular,
      'feature_reduced_commission' => feature_reduced_commission,
      'feature_monthly_credits' => feature_monthly_credits,
      'feature_featured_home' => feature_featured_home,
      'feature_sponsored_search' => feature_sponsored_search,
      'feature_priority_support' => feature_priority_support,
      'feature_everything_master' => feature_everything_master,
      'feature_lowest_commission' => feature_lowest_commission,
      'feature_max_credits' => feature_max_credits,
      'feature_map_spotlight' => feature_map_spotlight,
      'feature_promotion_boost' => feature_promotion_boost,
      'feature_rich_media_banners' => feature_rich_media_banners,
      'feature_verified_badge' => feature_verified_badge,
      'feature_dedicated_manager' => feature_dedicated_manager,
      _ => humanizeFeatureKey(key),
    };
  }

  /// Localized descriptions for a whole plan `features` array.
  List<String> planFeatureLabels(List<String> keys) =>
      keys.map(planFeatureLabel).toList();
}

/// Turns an unmapped backend feature key into a readable sentence fragment.
///
/// `feature_free_drink_friday` becomes `Free drink friday`. Returns the raw
/// key unchanged when there is nothing left to humanize.
String humanizeFeatureKey(String key) {
  final stripped = key.startsWith('feature_') ? key.substring(8) : key;
  final words = stripped
      .split(RegExp(r'[_\-]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return key;
  final sentence = words.join(' ');
  return sentence[0].toUpperCase() + sentence.substring(1);
}
