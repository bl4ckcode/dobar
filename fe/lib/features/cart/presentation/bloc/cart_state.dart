import 'package:barz/features/cart/domain/models/cart_model.dart';
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

  const CartLoaded({required this.cart});

  @override
  List<Object?> get props => [cart];
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
