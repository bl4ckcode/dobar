import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/venues/domain/venue_category.dart';
import 'package:barz/features/venues/domain/venue_repository.dart';
import 'package:barz/features/venues/presentation/cubit/category_venues_cubit.dart';
import 'package:barz/features/venues/presentation/venue_presentation.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

const double kCategoryMaxContentWidth = 600;

String categoryTitle(AppLocalizations l10n, VenueCategory category) =>
    switch (category) {
      VenueCategory.bars => l10n.category_bars,
      VenueCategory.restaurants => l10n.category_restaurants,
      VenueCategory.clubs => l10n.category_clubs,
    };

/// Dedicated venue list for a Home category pill. Home stays unfiltered and
/// Find's map is untouched.
class CategoryVenuesPage extends StatelessWidget {
  final VenueCategory category;
  final VenueRepository? repository; // test seam

  const CategoryVenuesPage({
    super.key,
    required this.category,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final location = context.read<LocationCubit>().state.currentLocation;
    return BlocProvider(
      create: (_) => CategoryVenuesCubit(
        repository: repository ?? getItInjector<VenueRepository>(),
        category: category,
        latitude: location?.latitude,
        longitude: location?.longitude,
      )..load(),
      child: _CategoryVenuesView(category: category),
    );
  }
}

class _CategoryVenuesView extends StatefulWidget {
  final VenueCategory category;
  const _CategoryVenuesView({required this.category});

  @override
  State<_CategoryVenuesView> createState() => _CategoryVenuesViewState();
}

class _CategoryVenuesViewState extends State<_CategoryVenuesView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        context.read<CategoryVenuesCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _searchFocus.requestFocus();
    } else if (_search.text.isNotEmpty) {
      _search.clear();
      context.read<CategoryVenuesCubit>().setSearch('');
    }
  }

  Future<void> _openFilters() async {
    final cubit = context.read<CategoryVenuesCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _FiltersSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.category_venues_search_hint,
                  border: InputBorder.none,
                ),
                onChanged: context.read<CategoryVenuesCubit>().setSearch,
              )
            : Text(categoryTitle(l10n, widget.category)),
        actions: [
          IconButton(
            tooltip: l10n.category_venues_search,
            icon: Icon(_searching ? LucideIcons.x : LucideIcons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: l10n.category_venues_filter,
            icon: const Icon(LucideIcons.list_filter),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kCategoryMaxContentWidth,
            ),
            child: BlocBuilder<CategoryVenuesCubit, CategoryVenuesState>(
              builder: (context, state) => Column(
                children: [
                  if (!state.hasLocation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.map_pin_off,
                            size: 16,
                            color: colors.labelSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.category_venues_no_location,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.labelSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: _body(context, state, l10n, colors)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    CategoryVenuesState state,
    AppLocalizations l10n,
    DobarColors colors,
  ) {
    switch (state.status) {
      case CategoryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CategoryStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colors.labelSecondary, size: 32),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: context.read<CategoryVenuesCubit>().load,
                child: Text(l10n.home_retry),
              ),
            ],
          ),
        );
      case CategoryStatus.ready:
        if (state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.category_venues_empty,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.labelSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length + (state.loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final venue = state.items[index];
            return VenueListCard(
              name: venue.name,
              rating: venue.rating,
              distance: formatVenueDistance(venue.distanceMeters),
              imageUrl: venue.imageUrl,
              promotion: badgeFor(venue.primaryPromotion),
              promotionText: venue.promotionText,
              onTap: () => AppRoute.pushBar(context, venue.id),
            );
          },
        );
    }
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet();

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late double _rating;
  late bool _promos;
  late double _distance;

  @override
  void initState() {
    super.initState();
    final s = context.read<CategoryVenuesCubit>().state;
    _rating = s.minRating;
    _promos = s.promosOnly;
    _distance = s.maxDistanceKm.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = context.read<CategoryVenuesCubit>().state.hasLocation;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.category_venues_filter,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // Distance filtering is disabled without a location.
            Text(l10n.category_venues_max_distance(_distance.round())),
            Slider(
              value: _distance,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_distance.round()} km',
              onChanged: hasLocation
                  ? (v) => setState(() => _distance = v)
                  : null,
            ),
            Text(l10n.category_venues_min_rating(_rating.toStringAsFixed(1))),
            Slider(
              value: _rating,
              min: 0,
              max: 5,
              divisions: 10,
              label: _rating.toStringAsFixed(1),
              onChanged: (v) => setState(() => _rating = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.category_venues_promos_available),
              value: _promos,
              onChanged: (v) => setState(() => _promos = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _rating = 0;
                    _promos = false;
                    _distance = 50;
                  }),
                  child: Text(l10n.category_venues_clear),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    context.read<CategoryVenuesCubit>().applyFilters(
                      minRating: _rating,
                      promosOnly: _promos,
                      maxDistanceKm: _distance.round(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.category_venues_apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
