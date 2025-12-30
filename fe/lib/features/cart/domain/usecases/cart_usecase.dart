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

  Future<Either<Failure, CartItemModel>> addItem({
    required int menuItemId,
    required int barId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
  }) {
    return repository.addItem(
      menuItemId: menuItemId,
      barId: barId,
      menuItemName: menuItemName,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  Future<Either<Failure, CartItemModel>> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) {
    return repository.updateItemQuantity(itemId: itemId, quantity: quantity);
  }

  Future<Either<Failure, void>> removeItem(int itemId) {
    return repository.removeItem(itemId);
  }

  Future<Either<Failure, void>> clearCart() {
    return repository.clearCart();
  }

  Future<Either<Failure, CheckoutResult>> checkout({
    required String orderType,
    required String paymentMethod,
  }) {
    return repository.checkout(
        orderType: orderType, paymentMethod: paymentMethod);
  }
}
