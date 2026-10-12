import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_models.freezed.dart';
part 'subscription_models.g.dart';

@freezed
abstract class ProrationInfo with _$ProrationInfo {
  const factory ProrationInfo({
    @JsonKey(name: 'previous_plan') required String previousPlan,
    @JsonKey(name: 'new_plan') required String newPlan,
    @JsonKey(name: 'credit_amount_cents') required int creditAmountCents,
    @JsonKey(name: 'cycle_start') required DateTime cycleStart,
    @JsonKey(name: 'cycle_end') required DateTime cycleEnd,
    @JsonKey(name: 'upgrade_date') required DateTime upgradeDate,
  }) = _ProrationInfo;

  factory ProrationInfo.fromJson(Map<String, dynamic> json) =>
      _$ProrationInfoFromJson(json);
}

@freezed
abstract class SubscriptionCaptureResult with _$SubscriptionCaptureResult {
  const factory SubscriptionCaptureResult({
    @JsonKey(name: 'payment_id') required String paymentId,
    required String status,
    @JsonKey(name: 'amount_cents') required int amountCents,
    required String gateway,
    @JsonKey(name: 'captured_at') required DateTime capturedAt,
  }) = _SubscriptionCaptureResult;

  factory SubscriptionCaptureResult.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionCaptureResultFromJson(json);
}

@freezed
abstract class SubscriptionUpgradeResult with _$SubscriptionUpgradeResult {
  const factory SubscriptionUpgradeResult({
    @JsonKey(name: 'payment_id') required String paymentId,
    required String status,
    required String gateway,
    @JsonKey(name: 'gateway_id') String? gatewayId,
    required double amount,
    required String currency,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'proration_credit_cents') required int prorationCreditCents,
  }) = _SubscriptionUpgradeResult;

  factory SubscriptionUpgradeResult.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionUpgradeResultFromJson(json);
}
