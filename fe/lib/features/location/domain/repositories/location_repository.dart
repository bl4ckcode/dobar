import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';

abstract class LocationRepository {
  Future<Either<Failure, LocationModel>> getCurrentLocation();
  Future<Either<Failure, bool>> requestLocationPermission();
  Future<Either<Failure, bool>> checkLocationPermission();
  Future<Either<Failure, bool>> requestLocationService();
  Future<Either<Failure, bool>> checkLocationService();
  Future<Either<Failure, List<PartnerProximity>>> getNearbyPartners(LocationModel location, {double radiusInMeters = 100});
  Future<Either<Failure, void>> updateUserLocation(LocationModel location);
  Stream<LocationModel> getLocationStream();
  Future<Either<Failure, String>> getWazeDeepLink(LocationModel destination);
  Future<Either<Failure, String>> getGoogleMapsDeepLink(LocationModel destination);
  Future<Either<Failure, String>> getAppleMapsDeepLink(LocationModel destination);
}
