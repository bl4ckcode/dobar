import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_subscription.freezed.dart';
part 'ad_subscription.g.dart';

/// Subscription tier enum
enum SubscriptionTier { regular, master, vip }

/// Subscription status enum
enum SubscriptionStatus { active, cancelled, expired, pending }

/// Subscription plan model (from GET /advertising/plans)
@freezed
abstract class SubscriptionPlan with _$SubscriptionPlan {
  const factory SubscriptionPlan({
    required SubscriptionTier tier,
    required String name,
    required double price,
    @JsonKey(name: 'commission_rate') required double commissionRate,
    required List<String> features,
  }) = _SubscriptionPlan;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanFromJson(json);
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
