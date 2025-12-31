import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';
import 'package:dio/dio.dart';
import 'package:location/location.dart';

abstract class LocationDatasource {
  Future<LocationModel> getCurrentLocation();
  Future<bool> requestLocationPermission();
  Future<bool> checkLocationPermission();
  Future<List<PartnerProximity>> getNearbyPartners(LocationModel location, {double radiusInMeters = 100});
  Future<void> updateUserLocation(LocationModel location);
  Stream<LocationModel> getLocationStream();
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
    final locationData = await _location.getLocation();
    return LocationModel(
      latitude: locationData.latitude ?? 0,
      longitude: locationData.longitude ?? 0,
      accuracy: locationData.accuracy,
      altitude: locationData.altitude,
      speed: locationData.speed,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<bool> requestLocationPermission() async {
    final permission = await _location.requestPermission();
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
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get nearby partners', e.response?.statusCode);
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
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to update location', e.response?.statusCode);
    }
  }

  @override
  Stream<LocationModel> getLocationStream() {
    return _location.onLocationChanged.map((locationData) => LocationModel(
          latitude: locationData.latitude ?? 0,
          longitude: locationData.longitude ?? 0,
          accuracy: locationData.accuracy,
          altitude: locationData.altitude,
          speed: locationData.speed,
          timestamp: DateTime.now(),
        ));
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
