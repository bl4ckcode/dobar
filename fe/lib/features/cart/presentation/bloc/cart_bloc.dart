import 'package:barz/features/cart/domain/usecases/cart_usecase.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartUsecase cartUsecase;

  CartBloc({required this.cartUsecase}) : super(CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<UpdateCartItem>(_onUpdateCartItem);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
    on<Checkout>(_onCheckout);
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.getCart();
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (cart) => emit(CartLoaded(cart: cart)),
    );
  }

  Future<void> _onAddToCart(AddToCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.addItem(
      menuItemId: event.menuItemId,
      barId: event.barId,
      menuItemName: event.menuItemName,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
    );
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (item) {
        emit(CartItemAdded(item: item));
        add(LoadCart());
      },
    );
  }

  Future<void> _onUpdateCartItem(
      UpdateCartItem event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.updateItemQuantity(
      itemId: event.itemId,
      quantity: event.quantity,
    );
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (item) {
        emit(CartItemUpdated(item: item));
        add(LoadCart());
      },
    );
  }

  Future<void> _onRemoveFromCart(
      RemoveFromCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.removeItem(event.itemId);
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (_) {
        emit(CartItemRemoved());
        add(LoadCart());
      },
    );
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.clearCart();
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (_) => emit(CartCleared()),
    );
  }

  Future<void> _onCheckout(Checkout event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.checkout(
      orderType: event.orderType,
      paymentMethod: event.paymentMethod,
    );
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (checkoutResult) => emit(CheckoutSuccess(result: checkoutResult)),
    );
  }
}
