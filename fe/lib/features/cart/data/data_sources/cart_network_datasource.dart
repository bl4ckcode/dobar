import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/utils/idempotency.dart';

class CartNetworkDataSource {
  final Dio dio;
  final int? Function()? currentUserId;
  int? _ownerId;
  String? _checkoutKey;
  CheckoutResult? _pendingCheckout;

  CartNetworkDataSource({required this.dio, this.currentUserId});

  void _scopeToUser() {
    final userId = currentUserId?.call();
    if (userId != _ownerId) {
      _ownerId = userId;
      _checkoutKey = null;
      _pendingCheckout = null;
    }
  }

  Future<CartModel> getCart() async {
    _scopeToUser();
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
    _scopeToUser();
    try {
      if (_pendingCheckout != null && request.items.isNotEmpty) {
        _pendingCheckout = null;
        _checkoutKey = null;
      }
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
    _scopeToUser();
    try {
      await dio.delete('${ApiEndpoints.baseUrl}${ApiEndpoints.cart}');
      _checkoutKey = null;
      _pendingCheckout = null;
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
    _scopeToUser();
    try {
      if (_pendingCheckout != null) return _pendingCheckout!;
      _checkoutKey ??= IdempotencyKey.forOrder(null, 'checkout');
      final data = {
        'defer_payment': true,
        'order_type': orderType,
        'payment_method': paymentMethod,
        'location_identifier': ?tableNumber,
        'special_instructions': ?specialInstructions,
        'active_promotion_ids': ?activePromotionIds,
      };

      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.cartCheckout}',
        data: data,
        options: Options(headers: {'X-Idempotency-Key': _checkoutKey}),
      );
      _pendingCheckout = CheckoutResult.fromJson(response.data);
      return _pendingCheckout!;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Checkout failed',
        e.response?.statusCode,
      );
    }
  }

  Future<CheckoutResult?> getPendingCheckout() async {
    _scopeToUser();
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.cartCheckout}/pending');
      final pending = response.data == null ? null : CheckoutResult.fromJson(response.data);
      _pendingCheckout = pending;
      return pending;
    } on DioException catch (error) {
      throw ServerException('Failed to load pending checkout', error.response?.statusCode);
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
