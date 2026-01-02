import 'package:barz/features/partners/domain/models/partner/product.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'partner_menu_model.freezed.dart';
part 'partner_menu_model.g.dart';

@freezed
abstract class PartnerMenu with _$PartnerMenu {
  const factory PartnerMenu({
    required String partnerId,
    List<Product>? items,
  }) = _PartnerMenu;

  factory PartnerMenu.fromJson(Map<String, dynamic> json) =>
      _$PartnerMenuFromJson(json);
}
