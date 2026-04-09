import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractBarRepository {
  Future<Either<Failure, List<BarModel>>> getNearbyBars(
    double latitude,
    double longitude,
    double maxDistance,
  );
  Future<Either<Failure, BarModel>> getBar(int barId);
  Future<Either<Failure, List<MenuModel>>> getBarMenus(int barId);
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
  });
  Future<Either<Failure, LocationConfig>> getLocationConfig(int barId);
  Future<Either<Failure, List<Promotion>>> getPromotions(int barId);
}
