import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';
import 'package:dio/dio.dart';
import 'package:location/location.dart';
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
  Future<void> openAppSettings(); // Added
  Future<bool> isLocationPermissionPermanentlyDenied(); // Added
  String getWazeDeepLink(LocationModel destination);
  String getGoogleMapsDeepLink(LocationModel destination);
  String getAppleMapsDeepLink(LocationModel destination);
}

class LocationDatasourceImpl implements LocationDatasource {
  final Dio dio;
  final Location _location = Location();

  LocationDatasourceImpl({required this.dio});

  @override
  Future<LocationModel> getCurrentLocation() async {
    // Check if location services are enabled first
    final serviceEnabled = await _location.serviceEnabled();
    debugPrint('[LocationDatasource] Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      throw Exception(
        "Location services are disabled. Please enable location services in Settings.",
      );
    }

    // Check permission again just to be sure
    final permissionGranted = await _location.hasPermission();
    debugPrint('[LocationDatasource] Permission status: $permissionGranted');
    if (permissionGranted == PermissionStatus.denied ||
        permissionGranted == PermissionStatus.deniedForever) {
      throw Exception(
        "Location permission denied. Please grant location permission.",
      );
    }

    try {
      final timeoutDuration = kDebugMode ? const Duration(seconds: 15) : const Duration(seconds: 15);
      debugPrint('[LocationDatasource] Fetch started (timeout: ${timeoutDuration.inSeconds}s)...');
      
      // -- NEW PARALLEL FETCH --
      // Race: Primary poll vs Stream event. First one wins.
      final locationData = await Future.any([
        _location.getLocation(),
        _location.onLocationChanged.first,
      ]).timeout(
        timeoutDuration,
        onTimeout: () {
          debugPrint('[LocationDatasource] Both fetch attempts timed out');
          throw TimeoutException("Location request timed out after ${timeoutDuration.inSeconds}s.");
        },
      );

      debugPrint('[LocationDatasource] Location received: ${locationData.latitude}, ${locationData.longitude}');
      
      if (locationData.latitude == null || locationData.longitude == null) {
        throw Exception("Invalid coordinates received from system");
      }

      return LocationModel(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        accuracy: locationData.accuracy,
        altitude: locationData.altitude,
        speed: locationData.speed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[LocationDatasource] Final location fetch attempt failed: $e');
      
      // -- DEBUG FALLBACK --
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
        throw Exception("Location request timed out. Please check your iOS Simulator > Features > Location settings.");
      }
      rethrow;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    final permission = await _location.requestPermission();
    if (permission == PermissionStatus.deniedForever) {
      // If it's denied forever, the dialog won't show.
      // We might want to throw a specific error or just return false.
      // The Bloc will handle it.
      return false;
    }
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  @override
  Future<bool> checkLocationPermission() async {
    final permission = await _location.hasPermission();
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  @override
  Future<bool> requestLocationService() async {
    final result = await _location.requestService();
    return result;
  }

  @override
  Future<bool> checkLocationService() async {
    final result = await _location.serviceEnabled();
    return result;
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
    final status = await ph.Permission.location.status;
    return status.isPermanentlyDenied;
  }

  @override
  Stream<LocationModel> getLocationStream() {
    return _location.onLocationChanged.map(
      (locationData) => LocationModel(
        latitude: locationData.latitude ?? 0,
        longitude: locationData.longitude ?? 0,
        accuracy: locationData.accuracy,
        altitude: locationData.altitude,
        speed: locationData.speed,
        timestamp: DateTime.now(),
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
