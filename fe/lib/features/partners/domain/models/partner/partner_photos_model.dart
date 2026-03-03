import 'package:freezed_annotation/freezed_annotation.dart';

part 'partner_photos_model.freezed.dart';
part 'partner_photos_model.g.dart';

@freezed
abstract class PartnerPhotos with _$PartnerPhotos {
  const factory PartnerPhotos({List<String>? images}) = _PartnerPhotos;

  factory PartnerPhotos.fromJson(Map<String, dynamic> json) =>
      _$PartnerPhotosFromJson(json);
}
