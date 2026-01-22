import 'package:freezed_annotation/freezed_annotation.dart';

part 'trending_drink.freezed.dart';
part 'trending_drink.g.dart';

@freezed
abstract class TrendingDrink with _$TrendingDrink {
  const factory TrendingDrink({
    required int id,
    required String name,
    @JsonKey(name: 'price_avg') double? priceAvg,
    double? price,
    String? description,
    String? category,
    @JsonKey(name: 'bar_name') String? barName,
    @JsonKey(name: 'bar_id') int? barId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'order_count') int? orderCount,
    @JsonKey(name: 'is_promoted') @Default(false) bool isPromoted,
    @JsonKey(name: 'menu_id') int? menuId,
    String? picture,
    @Default(true) bool available,
  }) = _TrendingDrink;

  factory TrendingDrink.fromJson(Map<String, dynamic> json) =>
      _$TrendingDrinkFromJson(json);
}
