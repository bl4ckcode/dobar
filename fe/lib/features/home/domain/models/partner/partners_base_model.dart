import 'personal_data.dart';
import 'location_data.dart';

class PartnersBaseModel {
  final LocationData _locationData;
  final PersonalData _personalData;
  final PartnerMenu menu;
  final PartnerMenu photos;
  final PartnerRating rating;
  late final PaymentData _payment;

  PartnersBaseModel(this._locationData, this._personalData, this.menu,
      this.photos, this.rating);
}

class PaymentData {
}

class PartnerRating {
}

abstract interface class PartnersPhotos {
  void getPhotos();
}

class PartnersPhotosImpl extends PartnersPhotos {
  List<String> images = [];

  @override
  void getPhotos() {

  }
}

class PartnerMenu {
  List<Product> products = [];
}

interface class Product {
  final String name;
  final double value;
  final String imageUrl;
  final int amount;
  final bool isAvailable;
  final ProductType productType;
  final double valueDiscount;
  final int selectedAmount;

  int totalSelected() {
    return 0;
  }

  double totalValue() {
    return 0.0;
  }

  Product(this.name, this.value, this.imageUrl, this.amount, this.isAvailable,
      this.productType, this.valueDiscount, this.selectedAmount);
}

enum ProductType {
  aqua,
  drink,
  food
}



