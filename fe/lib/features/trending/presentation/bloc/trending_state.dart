import 'package:equatable/equatable.dart';
import '../../domain/models/models.dart';

/// State for trending drinks BLoC.
class TrendingState extends Equatable {
  /// Trending drinks for home carousel.
  final List<TrendingDrink> trendingDrinks;
  
  /// Drink categories with labels.
  final List<DrinkCategory> drinkCategories;
  
  /// Food categories with labels.
  final List<DrinkCategory> foodCategories;
  
  /// Category item counts for badges.
  final Map<String, int> categoryCounts;
  
  /// Currently selected category's drinks.
  final List<TrendingDrink> categoryDrinks;
  
  /// Currently selected category name.
  final String? selectedCategory;
  
  /// Loading states.
  final bool isLoadingTrending;
  final bool isLoadingCategories;
  final bool isLoadingCategory;
  
  /// Error message.
  final String? error;

  const TrendingState({
    this.trendingDrinks = const [],
    this.drinkCategories = const [],
    this.foodCategories = const [],
    this.categoryCounts = const {},
    this.categoryDrinks = const [],
    this.selectedCategory,
    this.isLoadingTrending = false,
    this.isLoadingCategories = false,
    this.isLoadingCategory = false,
    this.error,
  });

  TrendingState copyWith({
    List<TrendingDrink>? trendingDrinks,
    List<DrinkCategory>? drinkCategories,
    List<DrinkCategory>? foodCategories,
    Map<String, int>? categoryCounts,
    List<TrendingDrink>? categoryDrinks,
    String? selectedCategory,
    bool? isLoadingTrending,
    bool? isLoadingCategories,
    bool? isLoadingCategory,
    String? error,
  }) {
    return TrendingState(
      trendingDrinks: trendingDrinks ?? this.trendingDrinks,
      drinkCategories: drinkCategories ?? this.drinkCategories,
      foodCategories: foodCategories ?? this.foodCategories,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      categoryDrinks: categoryDrinks ?? this.categoryDrinks,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingCategory: isLoadingCategory ?? this.isLoadingCategory,
      error: error,
    );
  }

  /// Check if any data is loading.
  bool get isLoading => isLoadingTrending || isLoadingCategories || isLoadingCategory;

  /// Get count for a specific category.
  int getCount(String category) => categoryCounts[category] ?? 0;

  @override
  List<Object?> get props => [
        trendingDrinks,
        drinkCategories,
        foodCategories,
        categoryCounts,
        categoryDrinks,
        selectedCategory,
        isLoadingTrending,
        isLoadingCategories,
        isLoadingCategory,
        error,
      ];
}
