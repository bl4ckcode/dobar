import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/repositories/abstract_cart_repository.dart';
import 'package:dartz/dartz.dart';

class CartUsecase {
  final AbstractCartRepository repository;

  CartUsecase({required this.repository});

  Future<Either<Failure, CartModel>> getCart() {
    return repository.getCart();
  }

  Future<Either<Failure, CartModel>> syncCart(CartSyncRequest request) {
    return repository.syncCart(request);
  }

  Future<Either<Failure, void>> clearCart() {
    return repository.clearCart();
  }

  Future<Either<Failure, CheckoutResult>> checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  }) {
    return repository.checkout(
      orderType: orderType,
      paymentMethod: paymentMethod,
      tableNumber: tableNumber,
      specialInstructions: specialInstructions,
      activePromotionIds: activePromotionIds,
    );
  }

  Future<Either<Failure, SpotAvailability>> checkSpotAvailability({
    required int barId,
    required String spotId,
  }) {
    return repository.checkSpotAvailability(barId: barId, spotId: spotId);
  }
}
