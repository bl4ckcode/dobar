import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repository/trending_repository.dart';
import 'trending_event.dart';
import 'trending_state.dart';

class TrendingBloc extends Bloc<TrendingEvent, TrendingState> {
  final TrendingRepository _repository;

  TrendingBloc(this._repository) : super(const TrendingState()) {
    on<LoadMostWanted>(_onLoadMostWanted);
    on<LoadHottest>(_onLoadHottest);
    on<LoadTrendingDrinks>(_onLoadTrendingDrinks);
    on<LoadCategories>(_onLoadCategories);
    on<LoadCategory>(_onLoadCategory);
    on<RefreshTrending>(_onRefresh);
  }

  Future<void> _onLoadMostWanted(
    LoadMostWanted event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(isLoadingMostWanted: true, error: null));

    try {
      final drinks = await _repository.getTrendingDrinks(
        limit: event.limit,
        type: 'most_wanted',
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(
        state.copyWith(mostWantedDrinks: drinks, isLoadingMostWanted: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMostWanted: false,
          error: 'Failed to load most wanted drinks: $e',
        ),
      );
    }
  }

  Future<void> _onLoadHottest(
    LoadHottest event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(isLoadingHottest: true, error: null));

    try {
      final drinks = await _repository.getTrendingDrinks(
        limit: event.limit,
        type: 'hottest',
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(state.copyWith(hottestDrinks: drinks, isLoadingHottest: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingHottest: false,
          error: 'Failed to load hottest drinks: $e',
        ),
      );
    }
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
      emit(state.copyWith(trendingDrinks: drinks, isLoadingTrending: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingTrending: false,
          error: 'Failed to load trending drinks: $e',
        ),
      );
    }
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<TrendingState> emit,
  ) async {
    emit(state.copyWith(isLoadingCategories: true, error: null));

    try {
      final response = await _repository.getCategories();
      emit(
        state.copyWith(
          drinkCategories: response.drinkCategories,
          foodCategories: response.foodCategories,
          categoryCounts: response.categoryCounts,
          isLoadingCategories: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingCategories: false,
          error: 'Failed to load categories: $e',
        ),
      );
    }
  }

  Future<void> _onLoadCategory(
    LoadCategory event,
    Emitter<TrendingState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingCategory: true,
        selectedCategory: event.category,
        error: null,
      ),
    );

    try {
      final drinks = await _repository.getDrinksByCategory(
        event.category,
        limit: event.limit,
      );
      emit(state.copyWith(categoryDrinks: drinks, isLoadingCategory: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingCategory: false,
          error: 'Failed to load category: $e',
        ),
      );
    }
  }

  Future<void> _onRefresh(
    RefreshTrending event,
    Emitter<TrendingState> emit,
  ) async {
    add(const LoadMostWanted());
    add(const LoadHottest());
  }
}
