import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractCartRepository {
  Future<Either<Failure, CartModel>> getCart();

  Future<Either<Failure, CartModel>> syncCart(CartSyncRequest request);

  Future<Either<Failure, void>> clearCart();
  Future<Either<Failure, CheckoutResult>> checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  });

  Future<Either<Failure, SpotAvailability>> checkSpotAvailability({
    required int barId,
    required String spotId,
  });
}
