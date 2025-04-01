import 'package:freezed_annotation/freezed_annotation.dart';

part 'partners_params.freezed.dart';

part 'partners_params.g.dart';

@freezed
class PartnersParams with _$PartnersParams {
  const factory PartnersParams({
    double? latitude,
    double? longitude,
    double? maxDistance,
  }) = _PartnersParams;

  factory PartnersParams.fromJson(Map<String, dynamic> json) =>
      _$PartnersParamsFromJson(json);
}
