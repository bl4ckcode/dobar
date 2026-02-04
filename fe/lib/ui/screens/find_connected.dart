import 'dart:async';
import 'package:barz/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
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

const double _defaultLat = -23.5505;
const double _defaultLng = -46.6333;

const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#64779e"}]},
  {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#6f9ba5"}]},
  {"featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
  {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023e58"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "transit", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#3a4762"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
]
''';

class FindConnected extends StatelessWidget {
  const FindConnected({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getItInjector<LocationBloc>()..add(GetCurrentLocation()),
        ),
        BlocProvider(create: (_) => getItInjector<BarBloc>()),
        BlocProvider(create: (_) => getItInjector<PromotionsBloc>()),
      ],
      child: const FindConnectedView(),
    );
  }
}

class FindConnectedView extends StatefulWidget {
  const FindConnectedView({super.key});

  @override
  State<FindConnectedView> createState() => _FindConnectedViewState();
}

class _FindConnectedViewState extends State<FindConnectedView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Completer<GoogleMapController> _mapController = Completer();
  bool _showListPanel = false;
  late AnimationController _panelAnimController;
  late Animation<Offset> _panelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _panelAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData(context);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  void _toggleListPanel() {
    if (!mounted) return;
    setState(() {
      _showListPanel = !_showListPanel;
    });
    if (_showListPanel) {
      _panelAnimController.forward();
    } else {
      _panelAnimController.reverse();
    }
  }

  void _refreshData(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;

    context.read<LocationBloc>().add(GetCurrentLocation());
    context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
    context.read<PromotionsBloc>().add(
      LoadPromotions(latitude: lat, longitude: lng),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController.complete(controller);
  }

  void _showBarBottomSheet(BarModel bar) {
    final colors = context.dobarColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BarzRadii.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: BarzSpacing.lg),
            Row(
              children: [
                BarImage(
                  barId: bar.id,
                  imageUrl: bar.imageUrl,
                  imageUrlExpiration: bar.imageUrlExpiration,
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(BarzRadii.md),
                  errorWidget: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(BarzRadii.md),
                    ),
                    child: Icon(Icons.store, color: colors.labelSecondary),
                  ),
                ),
                const SizedBox(width: BarzSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bar.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.labelPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bar.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.labelSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bar.approximateLocation != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: colors.labelSelected,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(bar.approximateLocation! / 1000).toStringAsFixed(1)} km away',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.labelSelected,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BarzSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _BottomSheetButton(
                    icon: Icons.directions,
                    label: 'Navigate',
                    onTap: () => _launchNavigation(bar),
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: BarzSpacing.md),
                Expanded(
                  child: _BottomSheetButton(
                    icon: Icons.storefront,
                    label: 'View Bar',
                    onTap: () {
                      Navigator.pop(ctx);
                      AppRoute.pushBar(context, bar.id);
                    },
                    isPrimary: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BarzSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _launchNavigation(BarModel bar) async {
    Navigator.pop(context);

    final availableMaps = await ml.MapLauncher.installedMaps;
    if (availableMaps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No map apps installed')));
      return;
    }

    if (!mounted) return;

    final colors = context.dobarColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BarzRadii.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: BarzSpacing.lg),
            Text(
              'Navigate with',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
            ),
            const SizedBox(height: BarzSpacing.md),
            ...availableMaps.map(
              (map) => ListTile(
                leading: Icon(
                  _getMapIcon(map.mapType),
                  color: colors.labelSelected,
                ),
                title: Text(
                  map.mapName,
                  style: TextStyle(color: colors.labelPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  map.showMarker(
                    coords: ml.Coords(
                      0,
                      0,
                    ), // TODO: Use actual bar coordinates when available
                    title: bar.name,
                    description: bar.address,
                  );
                },
              ),
            ),
            const SizedBox(height: BarzSpacing.md),
          ],
        ),
      ),
    );
  }

  IconData _getMapIcon(ml.MapType mapType) {
    switch (mapType) {
      case ml.MapType.waze:
        return Icons.navigation;
      case ml.MapType.google:
        return Icons.map;
      case ml.MapType.apple:
        return Icons.map_outlined;
      default:
        return Icons.directions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state.currentLocation != null) {
            final lat = state.currentLocation!.latitude;
            final lng = state.currentLocation!.longitude;
            _mapController.future.then((controller) {
              controller.animateCamera(
                CameraUpdate.newLatLng(LatLng(lat, lng)),
              );
            });
          }
        },
        child: Stack(
          children: [
            _buildMap(context),
            _buildSearchBar(colors),
            _buildListFab(colors),
            _buildLocationFab(colors),
            if (_showListPanel) _buildListPanel(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final locationState = context.watch<LocationBloc>().state;
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;

    return GoogleMap(
      mapType: MapType.normal,
      style: _darkMapStyle,
      initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 15),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: _onMapCreated,
    );
  }

  Widget _buildSearchBar(DobarColors colors) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: colors.labelPrimary),
          decoration: InputDecoration(
            hintText: 'Search bars, restaurants...',
            hintStyle: TextStyle(color: colors.labelSecondary),
            prefixIcon: Icon(Icons.search, color: colors.labelSecondary),
            suffixIcon: IconButton(
              icon: Icon(Icons.tune, color: colors.labelSecondary),
              onPressed: () {},
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ).animate().fadeIn().slideY(begin: -0.2, end: 0),
    );
  }

  Widget _buildListFab(DobarColors colors) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton(
        heroTag: 'list_fab',
        onPressed: _toggleListPanel,
        backgroundColor: colors.buttonPrimary,
        child: Icon(
          _showListPanel ? Icons.close : Icons.list,
          color: colors.buttonOnPrimary,
        ),
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildLocationFab(DobarColors colors) {
    return Positioned(
      bottom: 170,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'location_fab',
        onPressed: () async {
          final locationState = context.read<LocationBloc>().state;
          final lat = locationState.currentLocation?.latitude ?? _defaultLat;
          final lng = locationState.currentLocation?.longitude ?? _defaultLng;
          final controller = await _mapController.future;
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
          );
        },
        backgroundColor: colors.surface,
        child: Icon(Icons.my_location, color: colors.labelPrimary),
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildListPanel(DobarColors colors) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SlideTransition(
        position: _panelSlideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(BarzSpacing.lg),
                  child: Row(
                    children: [
                      Text(
                        'Nearby Bars',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.labelPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleListPanel,
                        icon: Icon(Icons.close, color: colors.labelPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBarsList(colors)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarsList(DobarColors colors) {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, promoState) {
        final barsWithPromos = <int>{};
        for (final promo in promoState.promotions) {
          barsWithPromos.add(promo.barId);
        }

        return BlocBuilder<BarBloc, BarState>(
          builder: (context, state) {
            if (state is BarLoading) {
              return Center(
                child: CircularProgressIndicator(color: colors.labelSelected),
              );
            }
            if (state is BarError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colors.labelSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: TextStyle(color: colors.labelSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _refreshData(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.buttonPrimary,
                        foregroundColor: colors.buttonOnPrimary,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (state is BarsLoaded) {
              if (state.bars.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store, size: 48, color: colors.labelSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'No bars found nearby',
                        style: TextStyle(
                          color: colors.labelPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refreshData(context),
                color: colors.labelSelected,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarzSpacing.md,
                  ),
                  itemCount: state.bars.length,
                  itemBuilder: (context, index) {
                    final bar = state.bars[index];
                    final hasPromo = barsWithPromos.contains(bar.id);
                    return _buildPanelBarCard(bar, colors, hasPromo: hasPromo);
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

  Widget _buildPanelBarCard(
    BarModel bar,
    DobarColors colors, {
    bool hasPromo = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: BarzSpacing.sm),
      color: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      child: InkWell(
        onTap: () {
          _toggleListPanel();
          _showBarBottomSheet(bar);
        },
        borderRadius: BorderRadius.circular(BarzRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.sm),
          child: Row(
            children: [
              BarImage(
                barId: bar.id,
                imageUrl: bar.imageUrl,
                imageUrlExpiration: bar.imageUrlExpiration,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(BarzRadii.sm),
                errorWidget: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(BarzRadii.sm),
                  ),
                  child: Icon(
                    Icons.store,
                    color: colors.labelSecondary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: BarzSpacing.sm),
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
                              color: colors.labelPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasPromo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.buttonPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PROMO',
                              style: TextStyle(
                                color: colors.buttonOnPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (bar.approximateLocation != null)
                      Text(
                        '${(bar.approximateLocation! / 1000).toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: colors.labelSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.labelSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _BottomSheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BarzRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? colors.buttonPrimary : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? colors.buttonOnPrimary : colors.labelPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? colors.buttonOnPrimary : colors.labelPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
