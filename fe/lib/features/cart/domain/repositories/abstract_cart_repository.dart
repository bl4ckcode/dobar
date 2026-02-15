import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:dartz/dartz.dart';

abstract class AbstractCartRepository {
  Future<Either<Failure, CartModel>> getCart();
  Future<Either<Failure, CartItemModel>> addItem({
    required int menuItemId,
    required int barId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
  });
  Future<Either<Failure, CartItemModel>> updateItemQuantity({
    required int itemId,
    required int quantity,
  });
  Future<Either<Failure, void>> removeItem(int itemId);
  Future<Either<Failure, void>> clearCart();
  Future<Either<Failure, CheckoutResult>> checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  });

  Future<Either<Failure, CartModel>> calculateCart({
    required List<String> activePromotionIds,
  });

  Future<Either<Failure, SpotAvailability>> checkSpotAvailability({
    required int barId,
    required String spotId,
  });
}
