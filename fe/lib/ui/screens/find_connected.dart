import 'dart:async';
import 'package:barz/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // Added
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';

import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/shared/presentation/widget/bar_image.dart';
import 'package:barz/core/utils/marker_generator.dart';
import 'package:barz/core/design/components/location_permission_alert.dart';



const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]}
]
''';

const String _lightMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  }
]
''';

class FindConnected extends StatelessWidget {
  final GlobalKey<FindConnectedViewState>? viewKey;

  const FindConnected({super.key, this.viewKey});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // LocationCubit is provided by WireframeShell
        BlocProvider(create: (_) => getItInjector<BarBloc>()),
        BlocProvider(create: (_) => getItInjector<PromotionsBloc>()),
      ],
      child: FindConnectedView(key: viewKey),
    );
  }
}

class FindConnectedView extends StatefulWidget {
  const FindConnectedView({super.key});

  @override
  State<FindConnectedView> createState() => FindConnectedViewState();
}

class FindConnectedViewState extends State<FindConnectedView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final Completer<GoogleMapController> _mapController = Completer();
  bool _showListPanel = false;
  bool _isListExpanded = false;
  bool _isSearchExpanded = false;
  bool _hasBeenActivated = false; // Only load bars after user visits this tab
  bool _needsBarsLoad = false; // Flag to load bars once location is ready
  late AnimationController _panelAnimController;

  final List<BarModel> _displayedBars = [];

  final Set<Polyline> _polylines = {};
  final Map<String, BitmapDescriptor> _customMarkers = {};
  BarModel? _selectedDestinationBar;
  String? _routeDistance;
  String? _routeDuration;

  static const String _googleMapsApiKey =
      "AIzaSyBBEOwWrrA86ZTMfEtLnuhGn2D7MAg5jsU";

  final PolylinePoints _polylinePoints = PolylinePoints(
    apiKey: _googleMapsApiKey,
  );

  @override
  void initState() {
    super.initState();

    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Load bars when this view becomes visible
  /// Called by WireframeShell when user taps Find tab
  void loadBarsIfNeeded() {
    if (!mounted) return;

    _hasBeenActivated = true; // Mark as activated

    final locationState = context.read<LocationCubit>().state;
    final barBloc = context.read<BarBloc>();
    final barState = barBloc.state;

    // Only load if not already loaded or loading
    if (barState is! BarsLoaded && barState is! BarLoading) {
      if (locationState.currentLocation != null) {
        // Location is ready, load bars immediately
        final lat = locationState.currentLocation!.latitude;
        final lng = locationState.currentLocation!.longitude;
        debugPrint('[FindView] Loading bars on tab activation (location ready)');
        barBloc.add(LoadNearbyBars(latitude: lat, longitude: lng));
        _needsBarsLoad = false;
      } else {
        // Location not ready, set flag to load when it becomes available
        debugPrint('[FindView] Location not available, will load when ready');
        _needsBarsLoad = true;
      }
    }

    if (barState is BarsLoaded) {
      _filterBars(_searchController.text, barState.bars);
      _loadMarkers(barState.bars);
    }
  }

  /// Actually perform the bars load (called when location becomes available)
  void _doLoadBars(double lat, double lng) {
    final barBloc = context.read<BarBloc>();
    final barState = barBloc.state;
    if (barState is! BarsLoaded && barState is! BarLoading) {
      debugPrint('[FindView] Loading bars (deferred)');
      barBloc.add(LoadNearbyBars(latitude: lat, longitude: lng));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[FindView] App resumed, checking location state...');
      final locationState = context.read<LocationCubit>().state;
      if (locationState.currentLocation == null) {
        debugPrint('[FindView] Location still null on resume, re-triggering getCurrentLocation');
        context.read<LocationCubit>().getCurrentLocation();
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final barState = context.read<BarBloc>().state;
    if (barState is BarsLoaded) {
      _filterBars(query, barState.bars);
    }
  }

  void _filterBars(String query, List<BarModel> allBars) {
    // Current list is _displayedBars
    // New list calculation
    List<BarModel> newBars;
    if (query.isEmpty) {
      newBars = List.from(allBars);
    } else {
      final lowerQuery = query.toLowerCase();
      newBars = allBars.where((bar) {
        return bar.name.toLowerCase().contains(lowerQuery) ||
            bar.address.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    // Basic diffing to update AnimatedList
    // For simplicity in this iteration: clear and refill if significantly different
    // Or just simple remove/insert loop.

    // NOTE: A proper diff algorithm involves Myers Diff or similar.
    // Given the prototype nature, we will do a smart replace.

    setState(() {
      _displayedBars.clear();
      _displayedBars.addAll(newBars);
    });
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

  Future<void> _loadMarkers(List<BarModel> bars) async {
    for (final bar in bars) {
      if (!_customMarkers.containsKey(bar.id.toString())) {
        try {
          final marker = await MarkerGenerator.createCustomMarkerBitmap(
            bar.imageUrl,
            fallbackAssetPath: 'assets/images/cup_placeholder.jpg',
            borderColor: context.dobarColors.surfaceElevated,
          );
          if (mounted) {
            setState(() {
              _customMarkers[bar.id.toString()] = marker;
            });
          }
        } catch (e) {
          debugPrint('Error generating marker: $e');
        }
      }
    }
  }

  // void _refreshData(BuildContext context) {
  //   final locationState = context.read<LocationCubit>().state;
  //   final lat = locationState.currentLocation?.latitude ?? _defaultLat;
  //   final lng = locationState.currentLocation?.longitude ?? _defaultLng;

  //   context.read<LocationCubit>().getCurrentLocation();
  //   context.read<BarBloc>().add(LoadNearbyBars(lat: lat, lng: lng));
  //   context.read<PromotionsBloc>().add(
  //     LoadPromotions(latitude: lat, longitude: lng),
  //   );
  // }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController.complete(controller);
  }

  void _showBarsAtLocationSheet(List<BarModel> bars) {
    final colors = context.dobarColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
              '${bars.length} Bars at this location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
            ),
            const SizedBox(height: BarzSpacing.lg),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: bars.length,
                separatorBuilder: (ctx, idx) => Divider(
                  color: colors.surfaceElevated.withValues(alpha: 0.3),
                  height: 24,
                ),
                itemBuilder: (ctx, idx) {
                  final bar = bars[idx];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showBarBottomSheet(bar);
                    },
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
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(BarzRadii.sm),
                            ),
                            child: Icon(Icons.store, color: colors.labelSecondary, size: 20),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colors.labelPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bar.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.labelSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colors.labelSecondary,
                        ),
                      ],
                    ),
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
                  fallbackUrls: [
                    if (bar.coverUrl != null) bar.coverUrl!,
                    if (bar.logoUrl != null) bar.logoUrl!,
                    if (bar.photoUrls != null) ...bar.photoUrls!,
                  ],
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
                    label: 'Preview Route',
                    onTap: () => _handleNavigationRequest(bar),
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

  Future<void> _handleNavigationRequest(BarModel bar) async {
    Navigator.pop(context); // Close bottom sheet to show map

    setState(() {
      _selectedDestinationBar = bar;
    });

    final locationState = context.read<LocationCubit>().state;
    final userLoc = locationState.currentLocation;

    if (userLoc != null && bar.latitude != null && bar.longitude != null) {
      await _drawRoute(
        LatLng(userLoc.latitude, userLoc.longitude),
        LatLng(bar.latitude!, bar.longitude!),
      );
    }

    // if (!mounted) return;
    // _launchNavigation(bar); // Moved to manual button
  }

  void _clearRoute() {
    setState(() {
      _selectedDestinationBar = null;
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
    });
  }

  Future<void> _drawRoute(LatLng start, LatLng dest) async {
    final result = await _polylinePoints.getRouteBetweenCoordinatesV2(
      request: RoutesApiRequest(
        origin: PointLatLng(start.latitude, start.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        travelMode: TravelMode.driving,
      ),
    );

    if (result.routes.isNotEmpty) {
      final route = result.routes.first;
      final polylinePoints = route.polylinePoints ?? [];

      if (polylinePoints.isNotEmpty) {
        final points = polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Extract distance and duration from route
        String? distance;
        String? duration;

        // Use Route properties directly
        if (route.distanceMeters != null) {
          final distanceKm = route.distanceMeters! / 1000;
          distance = '${distanceKm.toStringAsFixed(1)} km';
        }

        if (route.duration != null) {
          final durationMin = (route.duration! / 60).round();
          duration = '$durationMin min';
        }

        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: const Color(0xFFEBC147),
              width: 5,
              points: points,
            ),
          );
          _routeDistance = distance;
          _routeDuration = duration;
        });

        final controller = await _mapController.future;
        LatLngBounds bounds = _boundsFromLatLngList(points);
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } else {
        debugPrint('Route found but no polyline points available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find route. Check internet connection.'),
            ),
          );
        }
      }
    } else {
      debugPrint(
        'No routes found. Error: ${result.errorMessage}, Status: ${result.status}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find route. Check internet connection.'),
          ),
        );
      }
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  Future<void> _launchNavigation(BarModel bar) async {
    if (bar.latitude == null || bar.longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Navigation not available for this location at the moment.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                  map.showMarker(
                    coords: ml.Coords(bar.latitude!, bar.longitude!),
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
    final locationState = context.watch<LocationCubit>().state;

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocListener<LocationCubit, LocationState>(
        listener: (context, state) {
          if (state.currentLocation != null) {
            final lat = state.currentLocation!.latitude;
            final lng = state.currentLocation!.longitude;
            debugPrint('[FindView] Location obtained: $lat, $lng');
            _mapController.future.then((controller) {
              controller.animateCamera(
                CameraUpdate.newLatLng(LatLng(lat, lng)),
              );
            });

            // Only auto-load bars if this tab has been activated AND we need bars
            if (_hasBeenActivated && _needsBarsLoad) {
              debugPrint('[FindView] Location ready, deferred loading bars');
              _doLoadBars(lat, lng);
              _needsBarsLoad = false; // Reset flag after loading
            }
          } else if (state.error != null) {
            debugPrint('[FindView] Location state has error: ${state.error}');
          }
        },
        child: Stack(
          children: [
            _buildMap(context),
            _buildLocationButton(colors),
            _buildListPanel(colors),
            // Route Info Overlay (Google Maps style)
            if (_selectedDestinationBar != null &&
                _polylines.isNotEmpty &&
                (_routeDistance != null || _routeDuration != null))
              _buildRouteInfoOverlay(colors),
            // Floating "Start Navigation" Button
            if (_selectedDestinationBar != null && _polylines.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _launchNavigation(_selectedDestinationBar!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.buttonPrimary,
                      foregroundColor: colors.buttonOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BarzRadii.xl),
                      ),
                      elevation: 8,
                    ),
                    icon: const Icon(Icons.navigation),
                    label: const Text(
                      'Open in Maps',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 1, end: 0),
                ),
              ),

            // Location Permission Alert
            if (locationState.currentLocation == null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: LocationPermissionAlert(
                  error: locationState.error,
                  isLoading: locationState.isLoading,
                  onGrant: () => context.read<LocationCubit>().getCurrentLocation(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final locationState = context.watch<LocationCubit>().state;
    const double defaultLat = -19.9191; // Belo Horizonte
    const double defaultLng = -43.9386;

    final lat = locationState.currentLocation?.latitude ?? defaultLat;
    final lng = locationState.currentLocation?.longitude ?? defaultLng;

    return BlocConsumer<BarBloc, BarState>(
      listener: (context, state) {
        if (state is BarsLoaded) {
          _loadMarkers(state.bars);
          _filterBars(_searchController.text, state.bars);
        }
      },
      builder: (context, barState) {
        final markers = <Marker>{};
        if (barState is BarsLoaded) {
          // Group bars by location
          final Map<LatLng, List<BarModel>> groupedBars = {};
          for (final bar in barState.bars) {
            if (bar.latitude != null && bar.longitude != null) {
              final pos = LatLng(bar.latitude!, bar.longitude!);
              groupedBars.putIfAbsent(pos, () => []).add(bar);
            }
          }

          groupedBars.forEach((pos, barsAtPos) {
            if (barsAtPos.length == 1) {
              final bar = barsAtPos.first;
              final customIcon = _customMarkers[bar.id.toString()];
              markers.add(
                Marker(
                  markerId: MarkerId(bar.id.toString()),
                  position: pos,
                  icon: customIcon ?? BitmapDescriptor.defaultMarker,
                  infoWindow: InfoWindow(title: bar.name),
                  onTap: () => _showBarBottomSheet(bar),
                ),
              );
            } else {
              // Cluster marker
              markers.add(
                Marker(
                  markerId: MarkerId('cluster_${pos.latitude}_${pos.longitude}'),
                  position: pos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(
                    title: '${barsAtPos.length} Bars here',
                    snippet: barsAtPos.map((b) => b.name).join(', '),
                  ),
                  onTap: () => _showBarsAtLocationSheet(barsAtPos),
                ),
              );
            }
          });
        }

        return GoogleMap(
          mapType: MapType.normal,
          style: Theme.of(context).brightness == Brightness.dark
              ? _darkMapStyle
              : _lightMapStyle,
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          buildingsEnabled: false,
          trafficEnabled: false,
          onMapCreated: _onMapCreated,
          markers: markers,
          polylines: _polylines,
        );
      },
    );
  }

  Widget _buildLocationButton(DobarColors colors) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'location_fab',
        onPressed: () async {
          final locationState = context.read<LocationCubit>().state;
          if (locationState.currentLocation == null) {
            context.read<LocationCubit>().getCurrentLocation();
            return;
          }
          final lat = locationState.currentLocation!.latitude;
          final lng = locationState.currentLocation!.longitude;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingTop = MediaQuery.of(context).padding.top;
    final navBarHeight = 80.0; // Approximate nav bar height

    // Panel width: 50% normally, 70% when search is expanded
    final panelWidth = screenWidth * (_isSearchExpanded ? 0.7 : 0.5);
    final peekWidth = screenWidth * 0.1; // 10% peeking
    final collapsedLeft = -(panelWidth - peekWidth);

    // Determine target left position based on expansion state
    // We reuse _showListPanel to mean "Expanded" (true) vs "Collapsed/Peeking" (false)
    final targetLeft = _showListPanel ? 0.0 : collapsedLeft;

    // Heights: 50% when collapsed (vertically), full (minus nav bar) when expanded (vertically)
    // The user said "without being expanded to the bottom", so maybe we simply use
    // the collapsedHeight logic for both, or keep the existing vertical expansion toggle as a separate state?
    // Let's keep _isListExpanded for vertical height.
    final collapsedHeight = screenHeight * 0.5;
    final expandedHeight = screenHeight - paddingTop - navBarHeight - 12;
    final currentHeight = _isListExpanded ? expandedHeight : collapsedHeight;

    return AnimatedPositioned(
      duration: 400.ms,
      curve: Curves.easeOutCubic,
      top: paddingTop,
      left: targetLeft,
      width: panelWidth,
      height: currentHeight,
      child: GestureDetector(
        onTap: _showListPanel ? null : _toggleListPanel, // Open if closed
        onHorizontalDragEnd: (details) {
          // Simple swipe handling
          if (details.primaryVelocity! > 0) {
            // Swipe Right -> Open
            if (!_showListPanel) _toggleListPanel();
          } else if (details.primaryVelocity! < 0) {
            // Swipe Left -> Close
            if (_showListPanel) _toggleListPanel();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Column(
              children: [
                // Header with search and close
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colors.surfaceElevated.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isSearchExpanded)
                        Flexible(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(
                                color: colors.labelPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                  color: colors.labelSecondary,
                                ),
                                filled: true,
                                fillColor: colors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: colors.labelSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchExpanded = false;
                                      _searchController.clear();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.search, color: colors.labelPrimary),
                          onPressed: () {
                            // Expand panel if needed when search clicked
                            if (!_showListPanel) _toggleListPanel();

                            setState(() {
                              _isSearchExpanded = true;
                            });
                          },
                        ),
                      if (!_isSearchExpanded) const Spacer(),
                      // Close button (only show when expanded, or maybe change icon)
                      if (_showListPanel)
                        IconButton(
                          icon: Icon(Icons.close, color: colors.labelPrimary),
                          onPressed: _toggleListPanel,
                        ),
                    ],
                  ),
                ),

                // List Area - show all bars with staggered fade
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _displayedBars.length,
                    itemBuilder: (context, index) {
                      final bar = _displayedBars[index];
                      return _buildPanelBarCard(
                            bar,
                            colors,
                            animation: const AlwaysStoppedAnimation(1),
                          )
                          .animate()
                          .fadeIn(delay: (80 * index).ms, duration: 400.ms)
                          .slideX(begin: -0.2, end: 0);
                    },
                  ),
                ),

                // Arrow Button at bottom with animation
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isListExpanded = !_isListExpanded;
                    });
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: colors.surfaceElevated.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Animated arrows (only when collapsed)
                            if (!_isListExpanded) ...[
                              Icon(
                                    Icons.keyboard_arrow_down,
                                    color: colors.labelPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                    size: 24,
                                  )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .fadeIn(duration: 600.ms)
                                  .fadeOut(delay: 600.ms, duration: 600.ms)
                                  .moveY(begin: -8, end: 8, duration: 1200.ms),
                              Icon(
                                    Icons.keyboard_arrow_down,
                                    color: colors.labelPrimary.withValues(
                                      alpha: 0.5,
                                    ),
                                    size: 24,
                                  )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .fadeIn(delay: 400.ms, duration: 600.ms)
                                  .fadeOut(delay: 1000.ms, duration: 600.ms)
                                  .moveY(
                                    begin: -8,
                                    end: 8,
                                    delay: 400.ms,
                                    duration: 1200.ms,
                                  ),
                            ],
                            // Main arrow
                            Icon(
                              _isListExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: colors.labelPrimary,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelBarCard(
    BarModel bar,
    DobarColors colors, {
    bool hasPromo = false,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(-0.2, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                // 1. Close panel
                _toggleListPanel();

                // 2. Animate Camera
                if (bar.latitude != null && bar.longitude != null) {
                  final controller = await _mapController.future;
                  await controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(bar.latitude!, bar.longitude!),
                      16,
                    ),
                  );
                  // Wait slightly for animation
                  await Future.delayed(const Duration(milliseconds: 600));
                }

                if (!mounted) return;

                // 3. Show Bottom Sheet
                _showBarBottomSheet(bar);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    BarImage(
                      barId: bar.id,
                      imageUrl: bar.imageUrl,
                      imageUrlExpiration: bar.imageUrlExpiration,
                      fallbackUrls: [
                        if (bar.coverUrl != null) bar.coverUrl!,
                        if (bar.logoUrl != null) bar.logoUrl!,
                        if (bar.photoUrls != null) ...bar.photoUrls!,
                      ],
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(12),
                      errorWidget: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.store, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bar.name,
                            style: TextStyle(
                              color: colors.labelPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bar.address,
                            style: TextStyle(
                              color: colors.labelSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasPromo) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6792FF,
                                ), // Accent color from SideBar
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PROMO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (bar.approximateLocation != null)
                      Text(
                        '${(bar.approximateLocation! / 1000).toStringAsFixed(1)}km',
                        style: TextStyle(
                          color: colors.labelSecondary, // Dobar color
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfoOverlay(DobarColors colors) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_routeDuration != null) ...[
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: colors.labelSelected,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _routeDuration!,
                    style: TextStyle(
                      color: colors.labelPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_routeDuration != null && _routeDistance != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      height: 16,
                      color: colors.labelSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                if (_routeDistance != null) ...[
                  Icon(Icons.straighten, size: 18, color: colors.labelSelected),
                  const SizedBox(width: 6),
                  Text(
                    _routeDistance!,
                    style: TextStyle(
                      color: colors.labelPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _clearRoute,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.labelSecondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.labelPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.5, end: 0),
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
