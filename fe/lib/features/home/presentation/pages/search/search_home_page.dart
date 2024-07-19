import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../../../../../core/utils/constant/colors.dart';

class SearchHomePage extends StatefulWidget {
  const SearchHomePage({super.key});

  @override
  State<SearchHomePage> createState() => _SearchHomePageState();
}

class _SearchHomePageState extends State<SearchHomePage> {
  static const brasiliaLatLng = LatLng(-15.793889, -47.882778);

  final Completer<GoogleMapController> _controller = Completer();

  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;

  BitmapDescriptor currentLocationIcon = BitmapDescriptor.defaultMarker;

  void getCurrentLocation() async {
    Location location = Location();
    GoogleMapController googleMapController = await _controller.future;

    location.getLocation().then(
      (location) {
        currentLocation = location;
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
  void initState() {
    getCurrentLocation();
    //getPolypoints();
    super.initState();
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
        child: googleMapWidget(),
      ),
    );
  }

  Widget googleMapWidget() {
    GoogleMap googleMapWidget = GoogleMap(
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
      // polylines: {
      //   Polyline(
      //     polylineId: const PolylineId("route"),
      //     points: polylineCoordinates,
      //     color: mainColor,
      //     width: 6,
      //   ),
      // },
      markers: const {
        // Marker(
        //   markerId: const MarkerId("currentLocation"),
        //   position: LatLng(
        //     currentLocation?.latitude ?? 0,
        //     currentLocation?.longitude ?? 0,
        //   ),
        // ),
        // const Marker(
        //   markerId: MarkerId("source"),
        //   position: sourceLocation,
        // ),
        // const Marker(
        //   markerId: MarkerId("destination"),
        //   position: destination,
        // ),
      },
      onMapCreated: (mapContrtoller) {
        _controller.complete(mapContrtoller);
      },
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(
            () => PanGestureRecognizer()..onEnd = (drag) {

            })
      },
    );

    return googleMapWidget;
  }
}
