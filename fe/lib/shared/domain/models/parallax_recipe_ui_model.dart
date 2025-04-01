class ParallaxRecipeUiModel {
  int id;
  String imageUrl;
  String name;
  String adress = "";
  String approximateLocation = "";
  double imageUrlExpiration = 0.0;

  ParallaxRecipeUiModel({
    required this.id,
    required this.imageUrl,
    required this.name,
    this.adress = "",
    this.approximateLocation = "",
    this.imageUrlExpiration = 0.0
  });

  bool isImageUrlExpired() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > imageUrlExpiration;
  }
}
