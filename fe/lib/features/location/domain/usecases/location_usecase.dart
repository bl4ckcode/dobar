import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';
import 'package:barz/features/location/domain/repositories/location_repository.dart';

class LocationUsecase {
  final LocationRepository _repository;
  static const double proximityThreshold = 100.0;

  LocationUsecase(this._repository);

  Future<Either<Failure, LocationModel>> getCurrentLocation() {
    return _repository.getCurrentLocation();
  }

  Future<Either<Failure, bool>> requestLocationPermission() {
    return _repository.requestLocationPermission();
  }

  Future<Either<Failure, bool>> checkLocationPermission() {
    return _repository.checkLocationPermission();
  }

  Future<Either<Failure, bool>> requestLocationService() {
    return _repository.requestLocationService();
  }

  Future<Either<Failure, bool>> checkLocationService() {
    return _repository.checkLocationService();
  }

  Future<Either<Failure, List<PartnerProximity>>> getNearbyPartners(
    LocationModel location, {
    double radiusInMeters = 100,
  }) {
    return _repository.getNearbyPartners(
      location,
      radiusInMeters: radiusInMeters,
    );
  }

  Future<Either<Failure, void>> updateUserLocation(LocationModel location) {
    return _repository.updateUserLocation(location);
  }

  Stream<LocationModel> getLocationStream() {
    return _repository.getLocationStream();
  }

  Future<Either<Failure, String>> getWazeDeepLink(LocationModel destination) {
    return _repository.getWazeDeepLink(destination);
  }

  Future<Either<Failure, String>> getGoogleMapsDeepLink(
    LocationModel destination,
  ) {
    return _repository.getGoogleMapsDeepLink(destination);
  }

  Future<Either<Failure, String>> getAppleMapsDeepLink(
    LocationModel destination,
  ) {
    return _repository.getAppleMapsDeepLink(destination);
  }

  bool isWithinProximity(double distance) {
    return distance <= proximityThreshold;
  }
}
