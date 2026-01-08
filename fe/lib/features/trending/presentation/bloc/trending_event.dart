import 'package:freezed_annotation/freezed_annotation.dart';

part 'trending_event.freezed.dart';

/// Events for trending drinks BLoC.
@freezed
sealed class TrendingEvent with _$TrendingEvent {
  /// Load trending drinks for home carousel.
  const factory TrendingEvent.loadTrendingDrinks({
    @Default(10) int limit,
    List<String>? categories,
  }) = LoadTrendingDrinks;

  /// Load all categories for filter UI.
  const factory TrendingEvent.loadCategories() = LoadCategories;

  /// Load drinks for a specific category.
  const factory TrendingEvent.loadCategory({
    required String category,
    @Default(20) int limit,
  }) = LoadCategory;

  /// Refresh all trending data.
  const factory TrendingEvent.refresh() = RefreshTrending;
}
