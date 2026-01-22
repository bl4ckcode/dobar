import 'package:equatable/equatable.dart';
import '../../domain/models/models.dart';

/// State for trending drinks BLoC.
class TrendingState extends Equatable {
  final List<TrendingDrink> trendingDrinks;
  final List<TrendingDrink> mostWantedDrinks;
  final List<TrendingDrink> hottestDrinks;
  final List<DrinkCategory> drinkCategories;
  final List<DrinkCategory> foodCategories;
  final Map<String, int> categoryCounts;
  final List<TrendingDrink> categoryDrinks;
  final String? selectedCategory;
  final bool isLoadingTrending;
  final bool isLoadingMostWanted;
  final bool isLoadingHottest;
  final bool isLoadingCategories;
  final bool isLoadingCategory;
  final String? error;

  const TrendingState({
    this.trendingDrinks = const [],
    this.mostWantedDrinks = const [],
    this.hottestDrinks = const [],
    this.drinkCategories = const [],
    this.foodCategories = const [],
    this.categoryCounts = const {},
    this.categoryDrinks = const [],
    this.selectedCategory,
    this.isLoadingTrending = false,
    this.isLoadingMostWanted = false,
    this.isLoadingHottest = false,
    this.isLoadingCategories = false,
    this.isLoadingCategory = false,
    this.error,
  });

  TrendingState copyWith({
    List<TrendingDrink>? trendingDrinks,
    List<TrendingDrink>? mostWantedDrinks,
    List<TrendingDrink>? hottestDrinks,
    List<DrinkCategory>? drinkCategories,
    List<DrinkCategory>? foodCategories,
    Map<String, int>? categoryCounts,
    List<TrendingDrink>? categoryDrinks,
    String? selectedCategory,
    bool? isLoadingTrending,
    bool? isLoadingMostWanted,
    bool? isLoadingHottest,
    bool? isLoadingCategories,
    bool? isLoadingCategory,
    String? error,
  }) {
    return TrendingState(
      trendingDrinks: trendingDrinks ?? this.trendingDrinks,
      mostWantedDrinks: mostWantedDrinks ?? this.mostWantedDrinks,
      hottestDrinks: hottestDrinks ?? this.hottestDrinks,
      drinkCategories: drinkCategories ?? this.drinkCategories,
      foodCategories: foodCategories ?? this.foodCategories,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      categoryDrinks: categoryDrinks ?? this.categoryDrinks,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      isLoadingMostWanted: isLoadingMostWanted ?? this.isLoadingMostWanted,
      isLoadingHottest: isLoadingHottest ?? this.isLoadingHottest,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingCategory: isLoadingCategory ?? this.isLoadingCategory,
      error: error,
    );
  }

  /// Check if any data is loading.
  bool get isLoading =>
      isLoadingTrending ||
      isLoadingMostWanted ||
      isLoadingHottest ||
      isLoadingCategories ||
      isLoadingCategory;

  int getCount(String category) => categoryCounts[category] ?? 0;

  @override
  List<Object?> get props => [
    trendingDrinks,
    mostWantedDrinks,
    hottestDrinks,
    drinkCategories,
    foodCategories,
    categoryCounts,
    categoryDrinks,
    selectedCategory,
    isLoadingTrending,
    isLoadingMostWanted,
    isLoadingHottest,
    isLoadingCategories,
    isLoadingCategory,
    error,
  ];
}
