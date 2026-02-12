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
import 'package:barz/core/utils/marker_generator.dart';

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
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
  {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023e58"}]},
  {"featureType": "transit", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "transit.station", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
]
 // ... existing dark style
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
  late Animation<double> _panelAnimation;
  List<BarModel> _filteredBars = [];

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
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.fastOutSlowIn,
    );

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData(context);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final barState = context.read<BarBloc>().state;
    if (barState is BarsLoaded) {
      _filterBars(query, barState.bars);
    }
  }

  void _filterBars(String query, List<BarModel> allBars) {
    setState(() {
      if (query.isEmpty) {
        _filteredBars = allBars;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredBars = allBars.where((bar) {
          return bar.name.toLowerCase().contains(lowerQuery) ||
              bar.address.toLowerCase().contains(lowerQuery);
        }).toList();
      }
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
            borderColor: context.dobarColors.buttonPrimary,
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

    final locationState = context.read<LocationBloc>().state;
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

    // Navigator.pop(context); // Removed redundant pop

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
            _buildListFab(colors),
            _buildLocationFab(colors),
            if (_showListPanel) _buildListPanel(colors),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final locationState = context.watch<LocationBloc>().state;
    final lat = locationState.currentLocation?.latitude ?? _defaultLat;
    final lng = locationState.currentLocation?.longitude ?? _defaultLng;

    return BlocConsumer<BarBloc, BarState>(
      listener: (context, state) {
        if (state is BarsLoaded) {
          _loadMarkers(state.bars);
        }
      },
      builder: (context, barState) {
        final markers = <Marker>{};
        if (barState is BarsLoaded) {
          for (final bar in barState.bars) {
            if (bar.latitude != null && bar.longitude != null) {
              final customIcon = _customMarkers[bar.id.toString()];
              markers.add(
                Marker(
                  markerId: MarkerId(bar.id.toString()),
                  position: LatLng(bar.latitude!, bar.longitude!),
                  icon: customIcon ?? BitmapDescriptor.defaultMarker,
                  infoWindow: InfoWindow(title: bar.name),
                  onTap: () => _showBarBottomSheet(bar),
                ),
              );
            }
          }
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

  Widget _buildListFab(DobarColors colors) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: FloatingActionButton(
        heroTag: 'list_fab',
        onPressed: _toggleListPanel,
        backgroundColor: colors.surface,
        elevation: 8,
        child: Icon(
          _showListPanel ? Icons.close : Icons.menu,
          color: colors.labelPrimary,
        ),
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildLocationFab(DobarColors colors) {
    return Positioned(
      bottom: 100,
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
      left: 0,
      bottom: 0,
      width: 288,
      child: AnimatedBuilder(
        animation: _panelAnimation,
        builder: (context, child) {
          final slideValue = _panelAnimation.value;
          return Transform.translate(
            offset: Offset(-288 * (1 - slideValue), 0),
            child: Opacity(opacity: slideValue, child: child),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF17203A),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BarzRadii.lg),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search partners...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Nearby Partners',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleListPanel,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "BROWSE",
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white70),
                    ),
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
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (state is BarError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (state is BarsLoaded) {
              if (_filteredBars.isEmpty && _searchController.text.isEmpty) {
                _filteredBars = state.bars;
              }

              final barsToShow = _filteredBars;

              if (barsToShow.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.store_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No partners found'
                              : 'No partners nearby',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: barsToShow.length,
                itemBuilder: (context, index) {
                  final bar = barsToShow[index];
                  final hasPromo = barsWithPromos.contains(bar.id);
                  return _buildPanelBarCard(
                        bar,
                        colors,
                        hasPromo: hasPromo,
                        index: index,
                      )
                      .animate()
                      .moveX(
                        begin: -20, // Slide from left to match panel
                        end: 0,
                        delay:
                            (index * 30).ms, // Reduced delay for snappier feel
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      )
                      .fadeIn(delay: (index * 30).ms, duration: 300.ms);
                },
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
    int index = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), // Semi-transparent card
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bar.address,
                        style: const TextStyle(
                          color: Colors.white70,
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
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
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
