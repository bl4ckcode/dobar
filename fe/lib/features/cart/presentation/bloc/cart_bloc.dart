import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/domain/usecases/cart_usecase.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartUsecase cartUsecase;
  final AbstractBarRepository barRepository;

  CartBloc({required this.cartUsecase, required this.barRepository})
    : super(CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<UpdateCartItem>(_onUpdateCartItem);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
    on<Checkout>(_onCheckout);
    on<LoadCheckoutConfig>(_onLoadCheckoutConfig);
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    final result = await cartUsecase.getCart();
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (cart) => emit(CartLoaded(cart: cart)),
    );
  }

  Future<void> _onLoadCheckoutConfig(
    LoadCheckoutConfig event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;

      final results = await Future.wait([
        barRepository.getLocationConfig(event.barId),
        barRepository.getPromotions(event.barId),
      ]);

      final locationResult = results[0] as Either<Failure, LocationConfig>;
      final promotionsResult = results[1] as Either<Failure, List<Promotion>>;

      LocationConfig? locationConfig = currentState.locationConfig;
      List<Promotion> promotions = currentState.activePromotions;

      locationResult.fold(
        (failure) => null, // Ignore error for now, use default or null
        (config) => locationConfig = config,
      );

      promotionsResult.fold((failure) => null, (promos) => promotions = promos);

      emit(
        currentState.copyWith(
          locationConfig: locationConfig,
          activePromotions: promotions,
        ),
      );
    }
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
    result.fold((failure) => emit(CartError(message: failure.errorMessage)), (
      item,
    ) {
      emit(CartItemAdded(item: item));
      add(LoadCart());
    });
  }

  Future<void> _onUpdateCartItem(
    UpdateCartItem event,
    Emitter<CartState> emit,
  ) async {
    emit(CartLoading());
    final result = await cartUsecase.updateItemQuantity(
      itemId: event.itemId,
      quantity: event.quantity,
    );
    result.fold((failure) => emit(CartError(message: failure.errorMessage)), (
      item,
    ) {
      emit(CartItemUpdated(item: item));
      add(LoadCart());
    });
  }

  Future<void> _onRemoveFromCart(
    RemoveFromCart event,
    Emitter<CartState> emit,
  ) async {
    emit(CartLoading());
    final result = await cartUsecase.removeItem(event.itemId);
    result.fold((failure) => emit(CartError(message: failure.errorMessage)), (
      _,
    ) {
      emit(CartItemRemoved());
      add(LoadCart());
    });
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
      tableNumber: event.tableNumber,
      specialInstructions: event.specialInstructions,
      activePromotionIds: event.activePromotionIds,
    );
    result.fold(
      (failure) => emit(CartError(message: failure.errorMessage)),
      (checkoutResult) => emit(CheckoutSuccess(result: checkoutResult)),
    );
  }
}
