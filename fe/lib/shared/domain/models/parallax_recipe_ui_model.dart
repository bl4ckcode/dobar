class ParallaxRecipeUiModel {
  String imageUrl;
  String name;
  String adress = "";
  String approximateLocation = "";

  ParallaxRecipeUiModel({required this.imageUrl, required this.name, this.adress = "", this.approximateLocation = ""});
}
