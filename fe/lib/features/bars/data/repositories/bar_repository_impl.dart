import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

class BarRepositoryImpl extends AbstractBarRepository {
  final BarNetworkDataSource networkDataSource;

  BarRepositoryImpl({required this.networkDataSource});

  @override
  Future<Either<Failure, List<BarModel>>> getNearbyBars(
    double latitude,
    double longitude,
    double maxDistance,
  ) async {
    try {
      final result = await networkDataSource.getNearbyBars(
        latitude,
        longitude,
        maxDistance,
      );
      if (kDebugMode) {
        for (var bar in result) {
          print("${bar.name} ${bar.latitude} ${bar.longitude} ${bar.address}");
        }
      }
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, BarModel>> getBar(int barId) async {
    try {
      final result = await networkDataSource.getBar(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<MenuModel>>> getBarMenus(int barId) async {
    try {
      // Use the method that fetches menus with their items
      final result = await networkDataSource.getBarMenusWithItems(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, BarModel>> createBar({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String phoneNumber,
    required String email,
    required String countryCode,
    String? businessId,
    String? businessIdType,
    String? stateRegistration,
    String? logoUrl,
    String? coverUrl,
    List<String>? photoUrls,
    Map<String, dynamic>? operatingHours,
    Map<String, dynamic>? bankAccount,
  }) async {
    try {
      final result = await networkDataSource.createBar(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phoneNumber: phoneNumber,
        email: email,
        countryCode: countryCode,
        businessId: businessId,
        businessIdType: businessIdType,
        stateRegistration: stateRegistration,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        photoUrls: photoUrls,
        operatingHours: operatingHours,
        bankAccount: bankAccount,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, LocationConfig>> getLocationConfig(int barId) async {
    try {
      final result = await networkDataSource.getLocationConfig(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<Promotion>>> getPromotions(int barId) async {
    try {
      final result = await networkDataSource.getActivePromotions(barId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
