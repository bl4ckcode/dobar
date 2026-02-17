import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';

part 'cart_state.freezed.dart';

@freezed
sealed class CartState with _$CartState {
  const factory CartState.initial() = CartInitial;
  const factory CartState.loading() = CartLoading;
  const factory CartState.loaded({
    required CartModel cart,
    int? barId,
    LocationConfig? locationConfig,
    @Default([]) List<Promotion> activePromotions,
    @Default([]) List<String> selectedPromotionIds,
    SpotAvailability? spotAvailability,
    @Default(false) bool isLoading,
    @Default(0) int version,
  }) = CartLoaded;
  const factory CartState.itemAdded({required CartItemModel item}) =
      CartItemAdded;
  const factory CartState.itemUpdated({required CartItemModel item}) =
      CartItemUpdated;
  const factory CartState.itemRemoved() = CartItemRemoved;
  const factory CartState.cleared() = CartCleared;
  const factory CartState.checkoutSuccess({required CheckoutResult result}) =
      CheckoutSuccess;
  const factory CartState.error({required String message}) = CartError;
}
