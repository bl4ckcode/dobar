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
  Future<Either<Failure, CartItemModel>> addItem({
    required int menuItemId,
    required int barId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
  }) async {
    try {
      final result = await networkDataSource.addItem(
        menuItemId: menuItemId,
        barId: barId,
        menuItemName: menuItemName,
        quantity: quantity,
        unitPrice: unitPrice,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, CartItemModel>> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) async {
    try {
      final result = await networkDataSource.updateItemQuantity(
        itemId: itemId,
        quantity: quantity,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> removeItem(int itemId) async {
    try {
      await networkDataSource.removeItem(itemId);
      return const Right(null);
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
  }) async {
    try {
      final result = await networkDataSource.checkout(
        orderType: orderType,
        paymentMethod: paymentMethod,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
