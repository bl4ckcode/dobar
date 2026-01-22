import '../models/models.dart';

/// Repository interface for trending drinks feature.
abstract class TrendingRepository {
  Future<List<TrendingDrink>> getTrendingDrinks({
    int limit = 10,
    List<String>? categories,
    String type = 'most_wanted',
    double? latitude,
    double? longitude,
  });

  /// Get all available categories with metadata.
  Future<TrendingCategoriesResponse> getCategories();

  /// Get drinks filtered by a specific category.
  Future<List<TrendingDrink>> getDrinksByCategory(
    String category, {
    int limit = 20,
  });
}
