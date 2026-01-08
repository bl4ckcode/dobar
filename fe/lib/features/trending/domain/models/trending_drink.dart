import 'package:freezed_annotation/freezed_annotation.dart';

part 'trending_drink.freezed.dart';
part 'trending_drink.g.dart';

/// A trending drink item from the discovery endpoint.
/// 
/// This represents menu items aggregated across all bars,
/// grouped by category for the "Most Desired Drinks" feature.
@freezed
abstract class TrendingDrink with _$TrendingDrink {
  const factory TrendingDrink({
    required int id,
    required String name,
    required double price,
    String? description,
    required String category,
    @Default(true) bool available,
    @JsonKey(name: 'menu_id') required int menuId,
    String? picture,
  }) = _TrendingDrink;

  factory TrendingDrink.fromJson(Map<String, dynamic> json) =>
      _$TrendingDrinkFromJson(json);
}
