import 'package:barz/features/partners/domain/models/partner/partners_base_model.dart';
import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';

extension PartnersBaseModelX on PartnersBaseModel {
  ParallaxRecipeUiModel toParallaxRecipeUiModel() {
    double distance = approximateLocation ?? 0.0;
    String formattedDistance;

    if (distance < 1000) {
      // If less than 1000, discard decimals and display in meters.
      formattedDistance = "${distance.toInt()}m";
    } else {
      // Otherwise, convert to km and display with one decimal place.
      double km = distance / 1000;
      formattedDistance = "${km.toStringAsFixed(1)}km";
    }

    return ParallaxRecipeUiModel(
      id: id,
      imageUrl: "",
      name: name,
      adress: address,
      approximateLocation: formattedDistance,
    );
  }
}

List<ParallaxRecipeUiModel> mapPartnersToUiModel(
    List<PartnersBaseModel> partners) {
  return partners.map((partner) => partner.toParallaxRecipeUiModel()).toList();
}
