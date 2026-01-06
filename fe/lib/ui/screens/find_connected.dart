import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/primitives/barz_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';
import 'package:barz/features/location/presentation/bloc/location_bloc.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/shared/presentation/widget/bar_image.dart';

/// Default fallback coordinates (São Paulo city center)
const double _defaultLat = -23.5505;
const double _defaultLng = -46.6333;

class FindConnected extends StatelessWidget {
  const FindConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getItInjector<LocationBloc>()..add(GetCurrentLocation()),
        ),
        BlocProvider(
          create: (_) => getItInjector<BarBloc>(),
        ),
        BlocProvider(
          create: (_) => getItInjector<PromotionsBloc>()..add(LoadPromotions()),
        ),
      ],
      child: const _FindConnectedView(),
    );
  }
}

class _FindConnectedView extends StatefulWidget {
  const _FindConnectedView();

  @override
  State<_FindConnectedView> createState() => _FindConnectedViewState();
}

class _FindConnectedViewState extends State<_FindConnectedView> {
  final TextEditingController _searchController = TextEditingController();
  bool _showMapView = false;
  bool _barsLoaded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBarsWithLocation(BuildContext context, LocationState locationState) {
    if (_barsLoaded) return;
    
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;
    
    context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
    _barsLoaded = true;
  }

  void _refreshData(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;
    
    context.read<LocationBloc>().add(GetCurrentLocation());
    context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
    context.read<PromotionsBloc>().add(LoadPromotions());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        // When location is obtained (either success or after loading completes), load bars
        if (!state.isLoading) {
          _loadBarsWithLocation(context, state);
        }
      },
      child: Scaffold(
        appBar: const BarzAppBar(title: 'Find'),
        body: Container(
          decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
          child: Column(
            children: [
              _buildSearchBar(),
              _buildViewToggle(),
              Expanded(child: _showMapView ? _buildMapPlaceholder() : _buildBarsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search bars, restaurants...',
            hintStyle: TextStyle(color: textTertiary),
            prefixIcon: Icon(Icons.search, color: textSecondary),
            suffixIcon: IconButton(
              icon: Icon(Icons.tune, color: textSecondary),
              onPressed: () {},
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              icon: Icons.list,
              label: 'List',
              isSelected: !_showMapView,
              onTap: () => setState(() => _showMapView = false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildToggleButton(
              icon: Icons.map,
              label: 'Map',
              isSelected: _showMapView,
              onTap: () => setState(() => _showMapView = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? barzBlack : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? barzBlack : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? barzYellow : textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? barzYellow : textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarsList() {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, promoState) {
        // Build a set of bar IDs that have promotions
        final barsWithPromos = <int>{};
        for (final promo in promoState.promotions) {
          barsWithPromos.add(promo.barId);
        }
        
        return BlocBuilder<BarBloc, BarState>(
          builder: (context, state) {
            if (state is BarLoading) {
              return const Center(child: CircularProgressIndicator(color: barzYellow));
            }
            if (state is BarError) {
              return _buildErrorState(state.message, () {
                _barsLoaded = false;
                _refreshData(context);
              });
            }
            if (state is BarsLoaded) {
              if (state.bars.isEmpty) {
                return _buildEmptyState();
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _barsLoaded = false;
                  _refreshData(context);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.bars.length,
                  itemBuilder: (context, index) {
                    final bar = state.bars[index];
                    final hasPromo = barsWithPromos.contains(bar.id);
                    return _buildBarCard(bar, index, hasPromo: hasPromo);
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildBarCard(BarModel bar, int index, {bool hasPromo = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BarzCard(
        child: InkWell(
          onTap: () => context.push('/bar/${bar.id}'),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                // Image with optional promo badge and auto URL refresh
                Stack(
                  children: [
                    BarImage(
                      barId: bar.id,
                      imageUrl: bar.imageUrl,
                      imageUrlExpiration: bar.imageUrlExpiration,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                      errorWidget: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: barzYellowSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.store, color: barzYellowDark, size: 32),
                      ),
                    ),
                    if (hasPromo)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: barzBlack,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            size: 14,
                            color: barzYellow,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bar.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasPromo)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: barzYellow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PROMO',
                                style: TextStyle(
                                  color: barzBlack,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bar.address,
                        style: TextStyle(color: textSecondary, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (bar.approximateLocation != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: barzYellowDark),
                            const SizedBox(width: 4),
                            Text(
                              '${(bar.approximateLocation! / 1000).toStringAsFixed(1)} km',
                              style: TextStyle(color: barzYellowDark, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textTertiary),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX(begin: 0.05, end: 0);
  }

  Widget _buildMapPlaceholder() {
    return Center(
      child: BarzCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, size: 64, color: textTertiary),
            const SizedBox(height: 16),
            Text(
              'Map View',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon - will show bars on an interactive map',
              style: TextStyle(color: textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: barzYellow, foregroundColor: barzBlack),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store, size: 64, color: textTertiary),
            const SizedBox(height: 16),
            Text(
              'No bars found nearby',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or location',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
