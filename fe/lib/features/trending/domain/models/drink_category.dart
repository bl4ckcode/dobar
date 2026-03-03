import 'package:freezed_annotation/freezed_annotation.dart';

part 'drink_category.freezed.dart';
part 'drink_category.g.dart';

/// Known drink categories for filtering and display.
///
/// These match the backend's category system and include
/// both drink and food categories.
enum DrinkCategoryType {
  @JsonValue('drinks_trending')
  drinksTrending,
  @JsonValue('cachaça_cocktails')
  cachacaCocktails,
  @JsonValue('drinks_classicos')
  drinksClassicos,
  @JsonValue('batidas')
  batidas,
  @JsonValue('cervejas')
  cervejas,
  @JsonValue('destilados')
  destilados,
  @JsonValue('sem_alcool')
  semAlcool,
  @JsonValue('petiscos_fritos')
  petiscosFritos,
  @JsonValue('petiscos_grelhados')
  petiscosGrelhados,
  @JsonValue('tabuas')
  tabuas,
  @JsonValue('especiais')
  especiais,
}

/// A drink or food category with label and description.
@freezed
abstract class DrinkCategory with _$DrinkCategory {
  const factory DrinkCategory({
    required String category,
    required String label, // e.g., "🔥 Em Alta"
    required String description,
  }) = _DrinkCategory;

  factory DrinkCategory.fromJson(Map<String, dynamic> json) =>
      _$DrinkCategoryFromJson(json);
}

/// Response from GET /menus/trending/categories
@freezed
abstract class TrendingCategoriesResponse with _$TrendingCategoriesResponse {
  const factory TrendingCategoriesResponse({
    @JsonKey(name: 'drink_categories')
    required List<DrinkCategory> drinkCategories,
    @JsonKey(name: 'food_categories')
    required List<DrinkCategory> foodCategories,
    @JsonKey(name: 'category_counts') required Map<String, int> categoryCounts,
  }) = _TrendingCategoriesResponse;

  factory TrendingCategoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$TrendingCategoriesResponseFromJson(json);
}
