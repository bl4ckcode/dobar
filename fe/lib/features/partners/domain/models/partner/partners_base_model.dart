import 'package:barz/features/partners/domain/models/partner/partner_photos_model.dart';

import 'partner_menu_model.dart';
import 'personal_data_model.dart';
import 'location_data_model.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'partners_base_model.freezed.dart';

part 'partners_base_model.g.dart';

@freezed
class PartnersBaseModel with _$PartnersBaseModel {
  const factory PartnersBaseModel({
    required int id,
    required int ownerId,
    required String phoneNumber,
    required String name,
    required String address,
    required String email,
    double? approximateLocation,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'image_url_expiration') double? imageUrlExpiration,
    // LocationData? locationData,
    // PersonalData? personalData,
    // PartnerMenu? menu,
    // PartnerPhotos? photos,
    // // PartnerRating? rating,
  }) = _PartnersBaseModel;

  factory PartnersBaseModel.fromJson(Map<String, dynamic> json) =>
      _$PartnersBaseModelFromJson(json);
}
