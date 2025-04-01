import 'package:freezed_annotation/freezed_annotation.dart';
import 'product_type.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    String? name,
    double? value,
    String? imageUrl,
    int? amount,
    bool? isAvailable,
    int? productType,
    double? valueDiscount,
    int? selectedAmount,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

extension ProductX on Product {
  /// Returns the total number of selected items.
  int? totalSelected() => selectedAmount;

  /// Returns the total value based on the selected amount and base value.
  double totalValue() => value! * selectedAmount!;
}