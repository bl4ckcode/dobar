import 'location_data_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'personal_data_model.freezed.dart';
part 'personal_data_model.g.dart';

@freezed
abstract class PersonalData with _$PersonalData {
  const factory PersonalData({
    String? id,
    String? completeAddress,
    String? email,
    String? name,
    LocationData? locationData,
  }) = _PersonalData;

  factory PersonalData.fromJson(Map<String, dynamic> json) =>
      _$PersonalDataFromJson(json);
}

extension PersonalDataX on PersonalData {
  /// Returns the full address (or performs any custom logic)
  String? getAddress() => completeAddress;
}
