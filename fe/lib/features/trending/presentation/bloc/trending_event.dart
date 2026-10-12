import 'package:freezed_annotation/freezed_annotation.dart';

part 'trending_event.freezed.dart';

@freezed
sealed class TrendingEvent with _$TrendingEvent {
  const factory TrendingEvent.loadMostWanted({
    @Default(10) int limit,
    double? latitude,
    double? longitude,
  }) = LoadMostWanted;

  const factory TrendingEvent.loadHottest({
    @Default(10) int limit,
    double? latitude,
    double? longitude,
  }) = LoadHottest;

  const factory TrendingEvent.loadTrendingDrinks({
    @Default(10) int limit,
    List<String>? categories,
  }) = LoadTrendingDrinks;

  const factory TrendingEvent.loadCategories() = LoadCategories;

  const factory TrendingEvent.loadCategory({
    required String category,
    @Default(20) int limit,
  }) = LoadCategory;

  const factory TrendingEvent.refresh() = RefreshTrending;
}
