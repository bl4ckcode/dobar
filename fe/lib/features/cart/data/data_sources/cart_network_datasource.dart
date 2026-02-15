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

  Future<CartModel> syncCart(CartSyncRequest request) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartSync}',
        data: request.toJson(),
      );
      return CartModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to sync cart',
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

  Future<SpotAvailability> checkSpotAvailability({
    required int barId,
    required String spotId,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.barSpotAvailability(barId, spotId)}',
      );
      return SpotAvailability.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to check spot availability',
        e.response?.statusCode,
      );
    }
  }
}
