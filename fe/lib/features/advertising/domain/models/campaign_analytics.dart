import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_analytics.freezed.dart';
part 'campaign_analytics.g.dart';

double _parseDouble(dynamic value) {
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  return 0.0;
}

num _parseNum(dynamic value) {
  if (value is String) return num.tryParse(value) ?? 0;
  if (value is num) return value;
  return 0;
}

int _parseInt(dynamic value) {
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is num) return value.toInt();
  return 0;
}

/// Complete campaign analytics response
@freezed
abstract class CampaignAnalytics with _$CampaignAnalytics {
  const factory CampaignAnalytics({
    @JsonKey(name: 'campaign_id') required int campaignId,
    @JsonKey(name: 'campaign_name') required String campaignName,
    @JsonKey(fromJson: _parseInt) required int impressions,
    @JsonKey(fromJson: _parseInt) required int clicks,
    @JsonKey(fromJson: _parseInt) required int conversions,
    @JsonKey(fromJson: _parseNum) required num ctr,
    @JsonKey(fromJson: _parseDouble) required double spend,
    @JsonKey(name: 'period_start') required DateTime periodStart,
    @JsonKey(name: 'period_end') required DateTime periodEnd,
  }) = _CampaignAnalytics;

  factory CampaignAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CampaignAnalyticsFromJson(json);
}
