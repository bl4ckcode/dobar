import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/location/data/datasources/location_datasource.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';
import 'package:barz/features/location/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDatasource _datasource;

  LocationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, LocationModel>> getCurrentLocation() async {
    try {
      final result = await _datasource.getCurrentLocation();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, bool>> requestLocationPermission() async {
    try {
      final result = await _datasource.requestLocationPermission();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, bool>> checkLocationPermission() async {
    try {
      final result = await _datasource.checkLocationPermission();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, bool>> requestLocationService() async {
    try {
      final result = await _datasource.requestLocationService();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, bool>> checkLocationService() async {
    try {
      final result = await _datasource.checkLocationService();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, List<PartnerProximity>>> getNearbyPartners(
    LocationModel location, {
    double radiusInMeters = 100,
  }) async {
    try {
      final result = await _datasource.getNearbyPartners(
        location,
        radiusInMeters: radiusInMeters,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserLocation(
    LocationModel location,
  ) async {
    try {
      await _datasource.updateUserLocation(location);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Stream<LocationModel> getLocationStream() {
    return _datasource.getLocationStream();
  }

  @override
  Future<Either<Failure, String>> getWazeDeepLink(
    LocationModel destination,
  ) async {
    try {
      final result = _datasource.getWazeDeepLink(destination);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, String>> getGoogleMapsDeepLink(
    LocationModel destination,
  ) async {
    try {
      final result = _datasource.getGoogleMapsDeepLink(destination);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, String>> getAppleMapsDeepLink(
    LocationModel destination,
  ) async {
    try {
      final result = _datasource.getAppleMapsDeepLink(destination);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}
