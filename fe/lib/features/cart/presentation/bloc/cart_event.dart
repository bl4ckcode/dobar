import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_event.freezed.dart';

@freezed
sealed class CartEvent with _$CartEvent {
  const factory CartEvent.loadCart({int? barId}) = LoadCart;
  const factory CartEvent.addToCart({
    required int menuItemId,
    required int barId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
  }) = AddToCart;
  const factory CartEvent.updateCartItem({
    required int menuItemId,
    required int quantity,
  }) = UpdateCartItem;
  const factory CartEvent.removeFromCart({required int menuItemId}) =
      RemoveFromCart;
  const factory CartEvent.decreaseCartItem({required int menuItemId}) =
      DecreaseCartItem;
  const factory CartEvent.clearCart() = ClearCart;
  const factory CartEvent.loadCheckoutConfig({required int barId}) =
      LoadCheckoutConfig;
  const factory CartEvent.checkout({
    required String orderType,
    required String paymentMethod,
    String? tableNumber,
    String? specialInstructions,
    List<String>? activePromotionIds,
  }) = Checkout;
  const factory CartEvent.syncCart() = SyncCart;
  const factory CartEvent.updateActivePromotions({
    required List<String> activePromotionIds,
  }) = UpdateActivePromotions;
  const factory CartEvent.checkSpotAvailability({
    required int barId,
    required String spotId,
  }) = CheckSpotAvailability;
}
