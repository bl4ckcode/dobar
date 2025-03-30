class ParallaxRecipeUiModel {
  int id;
  String imageUrl;
  String name;
  String adress = "";
  String approximateLocation = "";

  ParallaxRecipeUiModel({
    required this.id,
    required this.imageUrl,
    required this.name,
    this.adress = "",
    this.approximateLocation = "",
  });
}
