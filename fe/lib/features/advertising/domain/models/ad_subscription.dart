import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_subscription.freezed.dart';
part 'ad_subscription.g.dart';

double _doubleFromJson(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _intFromJson(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Subscription tier enum
enum SubscriptionTier { regular, master, vip }

/// Subscription status enum
enum SubscriptionStatus { active, cancelled, expired, pending }

/// Advertising credits bundled with a subscription plan.
///
/// Parsed from the `credits` object of `GET /advertising/plans`, e.g.
/// `{"featured_hours": 12, "search_clicks": 1000, ...}`.
@freezed
abstract class PlanCredits with _$PlanCredits {
  const factory PlanCredits({
    @JsonKey(name: 'featured_hours', fromJson: _intFromJson)
    @Default(0)
    int featuredHours,
    @JsonKey(name: 'search_clicks', fromJson: _intFromJson)
    @Default(0)
    int searchClicks,
    @JsonKey(name: 'map_hours', fromJson: _intFromJson) @Default(0) int mapHours,
    @JsonKey(name: 'boost_impressions', fromJson: _intFromJson)
    @Default(0)
    int boostImpressions,
  }) = _PlanCredits;

  factory PlanCredits.fromJson(Map<String, dynamic> json) =>
      _$PlanCreditsFromJson(json);
}

/// Convenience helpers for surfaces that display plan entitlements.
extension PlanCreditsSummary on PlanCredits {
  /// True when the plan bundles at least one kind of advertising credit.
  bool get hasAny =>
      featuredHours > 0 ||
      searchClicks > 0 ||
      mapHours > 0 ||
      boostImpressions > 0;
}

/// Subscription plan model (from GET /advertising/plans)
@freezed
abstract class SubscriptionPlan with _$SubscriptionPlan {
  const factory SubscriptionPlan({
    required SubscriptionTier tier,
    required String name,
    @JsonKey(name: 'monthly_price', fromJson: _doubleFromJson)
    required double price,
    @JsonKey(name: 'annual_price', fromJson: _doubleFromJson)
    required double annualPrice,
    @JsonKey(name: 'commission_rate', fromJson: _doubleFromJson)
    required double commissionRate,
    required List<String> features,
    @JsonKey(fromJson: _planCreditsFromJson)
    @Default(PlanCredits())
    PlanCredits credits,
  }) = _SubscriptionPlan;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanFromJson(json);
}

/// Tolerates `credits` arriving as an object, as null, or missing entirely.
PlanCredits _planCreditsFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return PlanCredits.fromJson(value);
  if (value is Map) {
    return PlanCredits.fromJson(Map<String, dynamic>.from(value));
  }
  return const PlanCredits();
}

/// Commission rate as a display-ready percentage string (`0.12` -> `"12"`,
/// `0.075` -> `"7.5"`).
extension SubscriptionPlanCommission on SubscriptionPlan {
  String get commissionPercentLabel {
    final percent = commissionRate * 100;
    return percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
  }
}

/// Plans response with regional pricing
@freezed
abstract class PlansResponse with _$PlansResponse {
  const factory PlansResponse({
    @JsonKey(name: 'region_code') required String regionCode,
    required String currency,
    required List<SubscriptionPlan> plans,
  }) = _PlansResponse;

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'];
    final List<SubscriptionPlan> plansList;

    if (rawPlans is Map) {
      plansList = rawPlans.values
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      plansList = (rawPlans as List? ?? [])
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return PlansResponse(
      regionCode: json['region_code'] as String? ?? 'US',
      currency: json['currency'] as String? ?? 'USD',
      plans: plansList,
    );
  }
}

/// Bar subscription model
@freezed
abstract class AdSubscription with _$AdSubscription {
  const factory AdSubscription({
    required int id,
    @JsonKey(name: 'bar_id') required int barId,
    required SubscriptionTier tier,
    required SubscriptionStatus status,
    @JsonKey(name: 'current_period_start') required DateTime currentPeriodStart,
    @JsonKey(name: 'current_period_end') required DateTime currentPeriodEnd,
    @JsonKey(name: 'auto_renew') @Default(true) bool autoRenew,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AdSubscription;

  factory AdSubscription.fromJson(Map<String, dynamic> json) =>
      _$AdSubscriptionFromJson(json);
}
