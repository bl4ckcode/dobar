import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_campaign.freezed.dart';
part 'ad_campaign.g.dart';

/// Campaign type enum
enum CampaignType {
  featured,
  search,
  map,
  @JsonValue('promo_boost')
  promoBoost,
  banner,
}

/// Campaign status enum
enum CampaignStatus {
  pending,
  active,
  paused,
  completed,
  cancelled,
}

/// Budget type enum
enum BudgetType {
  credits,
  cash,
  mixed,
}

/// Campaign targeting options
@freezed
abstract class CampaignTargeting with _$CampaignTargeting {
  const factory CampaignTargeting({
    @JsonKey(name: 'radius_km') double? radiusKm,
    @JsonKey(name: 'target_audience') List<String>? targetAudience,
  }) = _CampaignTargeting;

  factory CampaignTargeting.fromJson(Map<String, dynamic> json) =>
      _$CampaignTargetingFromJson(json);
}

/// Campaign creative assets
@freezed
abstract class CampaignCreative with _$CampaignCreative {
  const factory CampaignCreative({
    String? tagline,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _CampaignCreative;

  factory CampaignCreative.fromJson(Map<String, dynamic> json) =>
      _$CampaignCreativeFromJson(json);
}

/// Ad campaign model
@freezed
abstract class AdCampaign with _$AdCampaign {
  const factory AdCampaign({
    required int id,
    @JsonKey(name: 'bar_id') required int barId,
    required String name,
    @JsonKey(name: 'campaign_type') required CampaignType campaignType,
    required CampaignStatus status,
    @JsonKey(name: 'budget_type') required BudgetType budgetType,
    @JsonKey(name: 'budget_amount') required double budgetAmount,
    @JsonKey(name: 'budget_spent') @Default(0.0) double budgetSpent,
    @Default(0) int impressions,
    @Default(0) int clicks,
    @Default(0) int conversions,
    double? ctr,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    CampaignTargeting? targeting,
    CampaignCreative? creative,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AdCampaign;

  factory AdCampaign.fromJson(Map<String, dynamic> json) =>
      _$AdCampaignFromJson(json);
}

/// Create campaign request
@freezed
abstract class CreateCampaignRequest with _$CreateCampaignRequest {
  const factory CreateCampaignRequest({
    @JsonKey(name: 'bar_id') required int barId,
    required String name,
    @JsonKey(name: 'campaign_type') required CampaignType campaignType,
    @JsonKey(name: 'budget_type') required BudgetType budgetType,
    @JsonKey(name: 'budget_amount') required double budgetAmount,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    CampaignTargeting? targeting,
    CampaignCreative? creative,
  }) = _CreateCampaignRequest;

  factory CreateCampaignRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCampaignRequestFromJson(json);
}
