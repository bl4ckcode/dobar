import 'product_type.dart';

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