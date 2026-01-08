import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repository/trending_repository.dart';
import 'trending_event.dart';
import 'trending_state.dart';

/// BLoC for managing trending drinks discovery.
/// 
/// Handles loading trending drinks, categories, and
/// category-specific drink lists for the home screen.
class TrendingBloc extends Bloc<TrendingEvent, TrendingState> {
  final TrendingRepository _repository;

  TrendingBloc(this._repository) : super(const TrendingState()) {
    on<LoadTrendingDrinks>(_onLoadTrendingDrinks);
    on<LoadCategories>(_onLoadCategories);
    on<LoadCategory>(_onLoadCategory);
    on<RefreshTrending>(_onRefresh);
  }

  Future<void> _onLoadTrendingDrinks(
    LoadTrendingDrinks event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(isLoadingTrending: true, error: null));
    
    try {
      final drinks = await _repository.getTrendingDrinks(
        limit: event.limit,
        categories: event.categories,
      );
      emit(state.copyWith(
        trendingDrinks: drinks,
        isLoadingTrending: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingTrending: false,
        error: 'Falha ao carregar drinks em alta: $e',
      ));
    }
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCategories: true, error: null));
    
    try {
      final response = await _repository.getCategories();
      emit(state.copyWith(
        drinkCategories: response.drinkCategories,
        foodCategories: response.foodCategories,
        categoryCounts: response.categoryCounts,
        isLoadingCategories: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCategories: false,
        error: 'Falha ao carregar categorias: $e',
      ));
    }
  }

  Future<void> _onLoadCategory(
    LoadCategory event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingCategory: true,
      selectedCategory: event.category,
      error: null,
    ));
    
    try {
      final drinks = await _repository.getDrinksByCategory(
        event.category,
        limit: event.limit,
      );
      emit(state.copyWith(
        categoryDrinks: drinks,
        isLoadingCategory: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCategory: false,
        error: 'Falha ao carregar categoria: $e',
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshTrending event,
    Emitter<TrendingState> emit,
  ) async {
    // Reload both trending and categories
    add(const LoadTrendingDrinks());
    add(const LoadCategories());
  }
}
