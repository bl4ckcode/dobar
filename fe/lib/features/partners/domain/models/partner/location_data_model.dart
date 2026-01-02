import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_data_model.freezed.dart';
part 'location_data_model.g.dart';

@freezed
abstract class LocationData with _$LocationData {
  const factory LocationData({
    double? latitude,
    double? longitude,
    double? maxDistance,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}
