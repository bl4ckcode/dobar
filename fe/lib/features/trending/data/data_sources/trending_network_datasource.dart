import 'package:dio/dio.dart';
import 'package:barz/core/api/api_endpoints.dart';
import '../../domain/models/models.dart';

/// Network datasource for trending drinks discovery.
///
/// Fetches aggregated drink data across all bars for
/// home screen carousels and category-based browsing.
class TrendingNetworkDatasource {
  final Dio dio;

  TrendingNetworkDatasource({required this.dio});

  /// Fetch trending drinks for home carousel.
  ///
  /// [limit] - Maximum items to return (1-50, default 20)
  /// [categories] - Comma-separated categories to filter (optional)
  ///
  /// Default categories: drinks_trending, cachaça_cocktails, drinks_classicos
  Future<List<TrendingDrink>> getTrendingDrinks({
    int limit = 10,
    List<String>? categories,
    String type = 'most_wanted',
    double? latitude,
    double? longitude,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'type': type};

    if (categories != null && categories.isNotEmpty) {
      queryParams['categories'] = categories.join(',');
    }

    if (latitude != null && longitude != null) {
      queryParams['latitude'] = latitude;
      queryParams['longitude'] = longitude;
    }

    final response = await dio.get(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.trendingDrinks}',
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data is Map && data['drinks'] is List) {
      return (data['drinks'] as List)
          .map((e) => TrendingDrink.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => TrendingDrink.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Fetch all available categories with labels and counts.
  ///
  /// Use for building category filter UI and showing
  /// popular categories on home screen.
  Future<TrendingCategoriesResponse> getCategories() async {
    final response = await dio.get(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.trendingCategories}',
    );

    return TrendingCategoriesResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Fetch drinks for a specific category.
  ///
  /// Convenience method for category detail pages.
  Future<List<TrendingDrink>> getDrinksByCategory(
    String category, {
    int limit = 20,
  }) async {
    return getTrendingDrinks(limit: limit, categories: [category]);
  }
}
