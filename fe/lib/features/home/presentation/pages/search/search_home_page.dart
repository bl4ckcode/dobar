import 'dart:async';

import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/advertising/domain/models/map_ad.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_bloc.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_event.dart';
import 'package:barz/features/advertising/presentation/bloc/advertising_state.dart';
import 'package:barz/features/advertising/presentation/widgets/ad_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class SearchHomePage extends StatefulWidget {
  const SearchHomePage({super.key});

  @override
  State<SearchHomePage> createState() => _SearchHomePageState();
}

class _SearchHomePageState extends State<SearchHomePage> {
  static const brasiliaLatLng = LatLng(-15.793889, -47.882778);

  final Completer<GoogleMapController> _controller = Completer();
  late AdvertisingBloc _advertisingBloc;
  late AdTrackingService _adTrackingService;

  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;
  Set<Marker> _adMarkers = {};

  BitmapDescriptor currentLocationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor? _sponsoredMarkerIcon;

  @override
  void initState() {
    super.initState();
    _advertisingBloc = getItInjector<AdvertisingBloc>();
    _adTrackingService = AdTrackingService();
    _loadSponsoredMarkerIcon();
    getCurrentLocation();
  }

  Future<void> _loadSponsoredMarkerIcon() async {
    _sponsoredMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueYellow,
    );
  }

  void getCurrentLocation() async {
    Location location = Location();
    GoogleMapController googleMapController = await _controller.future;

    location.getLocation().then(
      (loc) {
        currentLocation = loc;
        _loadMapAds();
      },
    );

    location.onLocationChanged.listen(
      (newLocation) {
        currentLocation = newLocation;

        googleMapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              zoom: 13.5,
              target: LatLng(
                newLocation.latitude ??
                    currentLocation?.latitude ??
                    brasiliaLatLng.latitude,
                newLocation.longitude ??
                    currentLocation?.latitude ??
                    brasiliaLatLng.latitude,
              ),
            ),
          ),
        );

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _loadMapAds() {
    final lat = currentLocation?.latitude;
    final lng = currentLocation?.longitude;
    if (lat != null && lng != null) {
      _advertisingBloc.add(
        AdvertisingEvent.loadMapAds(
          latitude: lat,
          longitude: lng,
          limit: 10,
        ),
      );
    }
  }

  void _buildAdMarkers(List<MapAd> mapAds) {
    _adMarkers = mapAds.map((ad) {
      return Marker(
        markerId: MarkerId('ad_${ad.campaignId}'),
        position: LatLng(ad.latitude, ad.longitude),
        icon: _sponsoredMarkerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: '⭐ ${ad.barName}',
          onTap: () {
            _adTrackingService.trackClick(
              ad.campaignId,
              AdPlacement.map,
              latitude: currentLocation?.latitude,
              longitude: currentLocation?.longitude,
            );
            context.push('/bar/${ad.barId}');
          },
        ),
        onTap: () {
          _adTrackingService.trackImpression(
            ad.campaignId,
            AdPlacement.map,
            latitude: currentLocation?.latitude,
            longitude: currentLocation?.longitude,
          );
        },
      );
    }).toSet();
  }

  //API Key AIzaSyBPLRryzGP6sIZSn3LTjEw9BpIVESOdXSA
  // void getPolypoints() async {
  //   PolylinePoints polylinePoints = PolylinePoints();
  //
  //   PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
  //     request: PolylineRequest(
  //         origin: PointLatLng(
  //           currentLocation?.latitude,
  //           currentLocation?.longitude,
  //         ),
  //         mode: TravelMode.driving),
  //   );
  //
  //   if (result.points.isNotEmpty) {
  //     for (var point in result.points) {
  //       polylineCoordinates.add(
  //         LatLng(
  //           point.latitude,
  //           point.longitude,
  //         ),
  //       );
  //       setState(() {});
  //     }
  //   }
  // }

  void setCustomMarkerIcon() {
    BitmapDescriptor.asset(
      ImageConfiguration.empty,
      "assets/pin_current_location.png",
    ).then(
      (icon) {
        currentLocationIcon = icon;
      },
    );
  }

  double getProperZoom() {
    if (currentLocation != null) {
      return 14.5;
    } else {
      return 6.25;
    }
  }

  @override
  void dispose() {
    _controller.future.then((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: BlocBuilder<AdvertisingBloc, AdvertisingState>(
            bloc: _advertisingBloc,
            builder: (context, adState) {
              _buildAdMarkers(adState.mapAds);
              return googleMapWidget();
            },
          ),
        ),
      ),
    );
  }

  Widget googleMapWidget() {
    return GoogleMap(
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      initialCameraPosition: CameraPosition(
        target: LatLng(
          currentLocation?.latitude ?? brasiliaLatLng.latitude,
          currentLocation?.longitude ?? brasiliaLatLng.longitude,
        ),
        zoom: getProperZoom(),
      ),
      markers: _adMarkers,
      onMapCreated: (mapController) {
        _controller.complete(mapController);
      },
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(
            () => PanGestureRecognizer()..onEnd = (drag) {})
      },
    );
  }
}
