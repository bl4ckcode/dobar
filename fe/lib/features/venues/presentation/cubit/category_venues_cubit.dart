import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/venue_category.dart';
import '../../domain/venue_list_item.dart';
import '../../domain/venue_repository.dart';

enum CategoryStatus { loading, ready, error }

class CategoryVenuesState {
  final CategoryStatus status;
  final List<VenueListItem> items;
  final bool hasMore;
  final bool loadingMore;
  final String search;
  final double minRating;
  final bool promosOnly;
  final int maxDistanceKm;
  final bool hasLocation;

  const CategoryVenuesState({
    this.status = CategoryStatus.loading,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.search = '',
    this.minRating = 0,
    this.promosOnly = false,
    this.maxDistanceKm = 50,
    this.hasLocation = false,
  });

  CategoryVenuesState copyWith({
    CategoryStatus? status,
    List<VenueListItem>? items,
    bool? hasMore,
    bool? loadingMore,
    String? search,
    double? minRating,
    bool? promosOnly,
    int? maxDistanceKm,
    bool? hasLocation,
  }) => CategoryVenuesState(
    status: status ?? this.status,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    search: search ?? this.search,
    minRating: minRating ?? this.minRating,
    promosOnly: promosOnly ?? this.promosOnly,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    hasLocation: hasLocation ?? this.hasLocation,
  );
}

/// Paged venue list for one category. Filters apply server-side before
/// pagination (20 per page); search is debounced and superseded responses are
/// discarded.
class CategoryVenuesCubit extends Cubit<CategoryVenuesState> {
  static const int pageSize = 20;

  final VenueRepository repository;
  final VenueCategory category;
  final double? latitude;
  final double? longitude;
  final Duration debounce;

  Timer? _timer;
  int _generation = 0;

  CategoryVenuesCubit({
    required this.repository,
    required this.category,
    this.latitude,
    this.longitude,
    this.debounce = const Duration(milliseconds: 350),
  }) : super(
         CategoryVenuesState(
           hasLocation: latitude != null && longitude != null,
         ),
       );

  VenueQuery _query(int offset) => VenueQuery(
    category: category.backendValue,
    latitude: latitude,
    longitude: longitude,
    search: state.search,
    minRating: state.minRating,
    promosOnly: state.promosOnly,
    maxDistanceKm: state.hasLocation ? state.maxDistanceKm : null,
    offset: offset,
    limit: pageSize,
  );

  Future<void> load() async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        items: const [],
        hasMore: false,
        loadingMore: false,
      ),
    );
    try {
      final page = await repository.fetch(_query(0));
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: CategoryStatus.ready,
          items: page.items,
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(status: CategoryStatus.error));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    if (state.status != CategoryStatus.ready) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await repository.fetch(_query(state.items.length));
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (generation != _generation || isClosed) return;
      emit(state.copyWith(loadingMore: false, hasMore: false));
    }
  }

  void setSearch(String value) {
    emit(state.copyWith(search: value));
    _timer?.cancel();
    _timer = Timer(debounce, load);
  }

  void applyFilters({
    required double minRating,
    required bool promosOnly,
    required int maxDistanceKm,
  }) {
    _timer?.cancel();
    emit(
      state.copyWith(
        minRating: minRating,
        promosOnly: promosOnly,
        maxDistanceKm: maxDistanceKm.clamp(1, 50),
      ),
    );
    load();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _generation++;
    return super.close();
  }
}
