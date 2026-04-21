import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

abstract class LocationDatasource {
  Future<LocationModel> getCurrentLocation();
  Future<bool> requestLocationPermission();
  Future<bool> checkLocationPermission();
  Future<bool> requestLocationService();
  Future<bool> checkLocationService();
  Future<List<PartnerProximity>> getNearbyPartners(
    LocationModel location, {
    double radiusInMeters = 100,
  });
  Future<void> updateUserLocation(LocationModel location);
  Stream<LocationModel> getLocationStream();
  Future<void> openAppSettings();
  Future<bool> isLocationPermissionPermanentlyDenied();
  String getWazeDeepLink(LocationModel destination);
  String getGoogleMapsDeepLink(LocationModel destination);
  String getAppleMapsDeepLink(LocationModel destination);
}

class LocationDatasourceImpl implements LocationDatasource {
  final Dio dio;

  LocationDatasourceImpl({required this.dio});

  @override
  Future<LocationModel> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        "Location services are disabled. Please enable location services in Settings.",
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Location permissions are permanently denied, we cannot request permissions.",
      );
    }

    try {
      debugPrint('[LocationDatasource] Fetching current position...');
      
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: true,
          showBackgroundLocationIndicator: false,
        ),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[LocationDatasource] Position received: ${position.latitude}, ${position.longitude}');

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('[LocationDatasource] Error fetching location: $e');
      
      if (kDebugMode) {
        debugPrint('[LocationDatasource] ⚠️ FALLBACK: Simulator/Device timed out. Providing Belo Horizonte location for development.');
        return LocationModel(
          latitude: -19.9191, // Belo Horizonte Center
          longitude: -43.9386,
          accuracy: 10.0,
          altitude: 0.0,
          speed: 0.0,
          timestamp: DateTime.now(),
        );
      }

      if (e is TimeoutException) {
        throw Exception("Location request timed out. Please check your GPS signal or simulator settings.");
      }
      rethrow;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestLocationService() async {
    // Geolocator doesn't have a direct "requestService" like 'location' package.
    // It usually directs user to settings. 
    // However, some platforms show a dialog.
    // We'll use the existing permission_handler or check status.
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return await Geolocator.isLocationServiceEnabled();
    }
    return true;
  }

  @override
  Future<bool> checkLocationService() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<List<PartnerProximity>> getNearbyPartners(
    LocationModel location, {
    double radiusInMeters = 100,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.bars}/nearby',
        queryParameters: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'radius': radiusInMeters,
        },
      );
      return (response.data as List)
          .map((json) => PartnerProximity.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get nearby partners',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> updateUserLocation(LocationModel location) async {
    try {
      await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userProfile}/location',
        data: location.toJson(),
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to update location',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  @override
  Future<bool> isLocationPermissionPermanentlyDenied() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  @override
  Stream<LocationModel> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(
      (position) => LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        timestamp: position.timestamp,
      ),
    );
  }

  @override
  String getWazeDeepLink(LocationModel destination) {
    return 'https://waze.com/ul?ll=${destination.latitude},${destination.longitude}&navigate=yes';
  }

  @override
  String getGoogleMapsDeepLink(LocationModel destination) {
    return 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
  }

  @override
  String getAppleMapsDeepLink(LocationModel destination) {
    return 'https://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}';
  }
}
