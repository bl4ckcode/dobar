import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:equatable/equatable.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final CartModel cart;
  final int? barId;
  final LocationConfig? locationConfig;
  final List<Promotion> activePromotions;
  final List<String> selectedPromotionIds;
  final SpotAvailability? spotAvailability;
  final bool isLoading;
  final int version;

  const CartLoaded({
    required this.cart,
    this.barId,
    this.locationConfig,
    this.activePromotions = const [],
    this.selectedPromotionIds = const [],
    this.spotAvailability,
    this.isLoading = false,
    this.version = 0,
  });

  CartLoaded copyWith({
    CartModel? cart,
    int? barId,
    LocationConfig? locationConfig,
    List<Promotion>? activePromotions,
    List<String>? selectedPromotionIds,
    SpotAvailability? spotAvailability,
    bool? isLoading,
    int? version,
  }) {
    return CartLoaded(
      cart: cart ?? this.cart,
      barId: barId ?? this.barId,
      locationConfig: locationConfig ?? this.locationConfig,
      activePromotions: activePromotions ?? this.activePromotions,
      selectedPromotionIds: selectedPromotionIds ?? this.selectedPromotionIds,
      spotAvailability: spotAvailability ?? this.spotAvailability,
      isLoading: isLoading ?? this.isLoading,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    cart,
    barId,
    locationConfig,
    activePromotions,
    selectedPromotionIds,
    spotAvailability,
    isLoading,
    version,
  ];
}

class CartItemAdded extends CartState {
  final CartItemModel item;

  const CartItemAdded({required this.item});

  @override
  List<Object?> get props => [item];
}

class CartItemUpdated extends CartState {
  final CartItemModel item;

  const CartItemUpdated({required this.item});

  @override
  List<Object?> get props => [item];
}

class CartItemRemoved extends CartState {}

class CartCleared extends CartState {}

class CheckoutSuccess extends CartState {
  final CheckoutResult result;

  const CheckoutSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}

class CartError extends CartState {
  final String message;

  const CartError({required this.message});

  @override
  List<Object?> get props => [message];
}
