import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_analytics.freezed.dart';
part 'campaign_analytics.g.dart';

/// Daily breakdown metrics
@freezed
class DailyMetrics with _$DailyMetrics {
  const factory DailyMetrics({
    required String date,
    required int impressions,
    required int clicks,
    required int conversions,
  }) = _DailyMetrics;

  factory DailyMetrics.fromJson(Map<String, dynamic> json) =>
      _$DailyMetricsFromJson(json);
}

/// Campaign metrics summary
@freezed
class CampaignMetrics with _$CampaignMetrics {
  const factory CampaignMetrics({
    required int impressions,
    required int clicks,
    required int conversions,
    required double ctr,
    @JsonKey(name: 'conversion_rate') required double conversionRate,
    @JsonKey(name: 'cost_per_click') required double costPerClick,
    @JsonKey(name: 'cost_per_conversion') required double costPerConversion,
  }) = _CampaignMetrics;

  factory CampaignMetrics.fromJson(Map<String, dynamic> json) =>
      _$CampaignMetricsFromJson(json);
}

/// Budget breakdown
@freezed
class BudgetBreakdown with _$BudgetBreakdown {
  const factory BudgetBreakdown({
    required double total,
    required double spent,
    required double remaining,
    @JsonKey(name: 'daily_average') required double dailyAverage,
  }) = _BudgetBreakdown;

  factory BudgetBreakdown.fromJson(Map<String, dynamic> json) =>
      _$BudgetBreakdownFromJson(json);
}

/// Date range for analytics
@freezed
class DateRange with _$DateRange {
  const factory DateRange({
    required DateTime start,
    required DateTime end,
  }) = _DateRange;

  factory DateRange.fromJson(Map<String, dynamic> json) =>
      _$DateRangeFromJson(json);
}

/// Complete campaign analytics response
@freezed
class CampaignAnalytics with _$CampaignAnalytics {
  const factory CampaignAnalytics({
    @JsonKey(name: 'campaign_id') required int campaignId,
    @JsonKey(name: 'campaign_name') required String campaignName,
    @JsonKey(name: 'campaign_type') required String campaignType,
    required String status,
    @JsonKey(name: 'date_range') required DateRange dateRange,
    required CampaignMetrics metrics,
    required BudgetBreakdown budget,
    @JsonKey(name: 'daily_breakdown') required List<DailyMetrics> dailyBreakdown,
  }) = _CampaignAnalytics;

  factory CampaignAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CampaignAnalyticsFromJson(json);
}
