import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/cart/data/data_sources/cart_network_datasource.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/repositories/abstract_cart_repository.dart';
import 'package:dartz/dartz.dart';

class CartRepositoryImpl extends AbstractCartRepository {
  final CartNetworkDataSource networkDataSource;

  CartRepositoryImpl({required this.networkDataSource});

  @override
  Future<Either<Failure, CartModel>> getCart() async {
    try {
      final result = await networkDataSource.getCart();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, CartModel>> syncCart(CartSyncRequest request) async {
    try {
      final result = await networkDataSource.syncCart(request);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> clearCart() async {
    try {
      await networkDataSource.clearCart();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, CheckoutResult>> checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  }) async {
    try {
      final result = await networkDataSource.checkout(
        orderType: orderType,
        paymentMethod: paymentMethod,
        tableNumber: tableNumber,
        specialInstructions: specialInstructions,
        activePromotionIds: activePromotionIds,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, SpotAvailability>> checkSpotAvailability({
    required int barId,
    required String spotId,
  }) async {
    try {
      final result = await networkDataSource.checkSpotAvailability(
        barId: barId,
        spotId: spotId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
