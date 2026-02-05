import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:dio/dio.dart';

class CartNetworkDataSource {
  final Dio dio;

  CartNetworkDataSource({required this.dio});

  Future<CartModel> getCart() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cart}',
      );
      return CartModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to fetch cart',
        e.response?.statusCode,
      );
    }
  }

  Future<CartItemModel> addItem({
    required int menuItemId,
    required int barId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartItems}',
        data: {
          'menu_item_id': menuItemId,
          'bar_id': barId,
          'menu_item_name': menuItemName,
          'quantity': quantity,
          'unit_price': unitPrice,
        },
      );
      return CartItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to add item',
        e.response?.statusCode,
      );
    }
  }

  Future<CartItemModel> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartItem(itemId)}',
        data: {'quantity': quantity},
      );
      return CartItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to update item',
        e.response?.statusCode,
      );
    }
  }

  Future<void> removeItem(int itemId) async {
    try {
      await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartItem(itemId)}',
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to remove item',
        e.response?.statusCode,
      );
    }
  }

  Future<void> clearCart() async {
    try {
      await dio.delete('${ApiEndpoints.baseUrl}${ApiEndpoints.cart}');
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to clear cart',
        e.response?.statusCode,
      );
    }
  }

  Future<CheckoutResult> checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  }) async {
    try {
      final data = {
        'order_type': orderType,
        'payment_method': paymentMethod,
        if (tableNumber != null) 'location_identifier': tableNumber,
        if (specialInstructions != null)
          'special_instructions': specialInstructions,
        if (activePromotionIds != null)
          'active_promotion_ids': activePromotionIds,
      };

      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartCheckout}',
        data: data,
      );
      return CheckoutResult.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Checkout failed',
        e.response?.statusCode,
      );
    }
  }
}
