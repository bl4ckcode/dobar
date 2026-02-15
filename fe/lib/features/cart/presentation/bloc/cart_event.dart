import 'package:equatable/equatable.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class LoadCart extends CartEvent {}

class AddToCart extends CartEvent {
  final int menuItemId;
  final int barId;
  final String menuItemName;
  final int quantity;
  final double unitPrice;

  const AddToCart({
    required this.menuItemId,
    required this.barId,
    required this.menuItemName,
    required this.quantity,
    required this.unitPrice,
  });

  @override
  List<Object?> get props => [
    menuItemId,
    barId,
    menuItemName,
    quantity,
    unitPrice,
  ];
}

class UpdateCartItem extends CartEvent {
  final int itemId;
  final int quantity;

  const UpdateCartItem({required this.itemId, required this.quantity});

  @override
  List<Object?> get props => [itemId, quantity];
}

class RemoveFromCart extends CartEvent {
  final int itemId;

  const RemoveFromCart({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class ClearCart extends CartEvent {}

class LoadCheckoutConfig extends CartEvent {
  final int barId;

  const LoadCheckoutConfig({required this.barId});

  @override
  List<Object?> get props => [barId];
}

class Checkout extends CartEvent {
  final String orderType;
  final String paymentMethod;
  final String? tableNumber;
  final String? specialInstructions;
  final List<String>? activePromotionIds;

  const Checkout({
    required this.orderType,
    required this.paymentMethod,
    this.tableNumber,
    this.specialInstructions,
    this.activePromotionIds,
  });

  @override
  List<Object?> get props => [
    orderType,
    paymentMethod,
    tableNumber,
    specialInstructions,
    activePromotionIds,
  ];
}

class SyncCart extends CartEvent {}

class UpdateActivePromotions extends CartEvent {
  final List<String> activePromotionIds;

  const UpdateActivePromotions({required this.activePromotionIds});

  @override
  List<Object?> get props => [activePromotionIds];
}

class CheckSpotAvailability extends CartEvent {
  final int barId;
  final String spotId;

  const CheckSpotAvailability({required this.barId, required this.spotId});

  @override
  List<Object?> get props => [barId, spotId];
}
