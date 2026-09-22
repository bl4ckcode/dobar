import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_campaign.freezed.dart';
part 'ad_campaign.g.dart';

double _doubleFromJson(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _doubleOrNullFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _intOrNullFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

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
enum CampaignStatus { pending, active, paused, completed, cancelled }

/// Backend wire name for a campaign type.
///
/// `CampaignType.name` cannot be used directly: it would send `promoBoost`
/// where the API expects `promo_boost`.
extension CampaignTypeWire on CampaignType {
  String get wireName => switch (this) {
    CampaignType.featured => 'featured',
    CampaignType.search => 'search',
    CampaignType.map => 'map',
    CampaignType.promoBoost => 'promo_boost',
    CampaignType.banner => 'banner',
  };
}

/// Budget type enum
enum BudgetType { credits, cash, mixed }

/// Campaign targeting options
@freezed
abstract class CampaignTargeting with _$CampaignTargeting {
  const factory CampaignTargeting({
    @JsonKey(name: 'radius_km', fromJson: _doubleOrNullFromJson)
    double? radiusKm,
    @JsonKey(name: 'target_audience') List<String>? targetAudience,
    @JsonKey(name: 'age_min', fromJson: _intOrNullFromJson) int? ageMin,
    @JsonKey(name: 'age_max', fromJson: _intOrNullFromJson) int? ageMax,
    @JsonKey(name: 'peak_hours_only') bool? peakHoursOnly,
    @JsonKey(name: 'budget_optimizer_enabled') bool? budgetOptimizerEnabled,
  }) = _CampaignTargeting;

  factory CampaignTargeting.fromJson(Map<String, dynamic> json) =>
      _$CampaignTargetingFromJson(json);
}

/// Campaign creative assets
@freezed
abstract class CampaignCreative with _$CampaignCreative {
  const factory CampaignCreative({
    String? title,
    String? tagline,
    String? cta,
    @JsonKey(name: 'promote_happy_hour') bool? promoteHappyHour,
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
    @JsonKey(name: 'budget_amount', fromJson: _doubleFromJson)
    required double budgetAmount,
    @JsonKey(name: 'budget_spent', fromJson: _doubleFromJson)
    @Default(0.0)
    double budgetSpent,
    @JsonKey(name: 'budget_remaining', fromJson: _doubleFromJson)
    @Default(0.0)
    double budgetRemaining,
    @Default(0) int impressions,
    @Default(0) int clicks,
    @Default(0) int conversions,
    @JsonKey(fromJson: _doubleOrNullFromJson) double? ctr,
    @JsonKey(name: 'start_time') required DateTime startDate,
    @JsonKey(name: 'end_time') DateTime? endDate,
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
    @JsonKey(name: 'budget_amount', fromJson: _doubleFromJson)
    required double budgetAmount,
    @JsonKey(name: 'start_time') required DateTime startDate,
    @JsonKey(name: 'end_time') DateTime? endDate,
    CampaignTargeting? targeting,
    CampaignCreative? creative,
    /// Share of the budget assigned to each `CampaignPlacement`, keyed by the
    /// backend placement name (e.g. `{"featured": 40.0, "search": 60.0}`).
    @JsonKey(name: 'placement_distribution') Map<String, double>? placementDistribution,
  }) = _CreateCampaignRequest;

  factory CreateCampaignRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCampaignRequestFromJson(json);
}
