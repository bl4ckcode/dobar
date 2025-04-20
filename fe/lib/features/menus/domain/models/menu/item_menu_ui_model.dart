class ItemMenuUiModel {
  late String img;
  late double imgUrlExpiration;
  late String title;
  late String description;
  late String price;

  bool isImageUrlExpired() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > imgUrlExpiration;
  }
}
