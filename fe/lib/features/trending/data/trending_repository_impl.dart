import '../domain/models/models.dart';
import '../domain/repository/trending_repository.dart';
import 'data_sources/trending_network_datasource.dart';

/// Implementation of TrendingRepository.
class TrendingRepositoryImpl implements TrendingRepository {
  final TrendingNetworkDatasource _datasource;

  TrendingRepositoryImpl(this._datasource);

  @override
  Future<List<TrendingDrink>> getTrendingDrinks({
    int limit = 10,
    List<String>? categories,
    String type = 'most_wanted',
    double? latitude,
    double? longitude,
  }) {
    return _datasource.getTrendingDrinks(
      limit: limit,
      categories: categories,
      type: type,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<TrendingCategoriesResponse> getCategories() {
    return _datasource.getCategories();
  }

  @override
  Future<List<TrendingDrink>> getDrinksByCategory(
    String category, {
    int limit = 20,
  }) {
    return _datasource.getDrinksByCategory(category, limit: limit);
  }
}
