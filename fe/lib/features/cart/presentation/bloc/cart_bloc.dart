import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart'
    hide CartItem, Promotion;
import 'package:barz/features/cart/domain/models/cart_models.dart'
    as legacy_models;
import 'package:barz/features/cart/domain/usecases/cart_usecase.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartUsecase cartUsecase;
  final AbstractBarRepository barRepository;

  CartBloc({required this.cartUsecase, required this.barRepository})
    : super(CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<UpdateCartItem>(_onUpdateCartItem);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<DecreaseCartItem>(_onDecreaseCartItem);
    on<ClearCart>(_onClearCart);
    on<Checkout>(_onCheckout);
    on<LoadCheckoutConfig>(_onLoadCheckoutConfig);
    on<UpdateActivePromotions>(_onUpdateActivePromotions);
    on<CheckSpotAvailability>(_onCheckSpotAvailability);

    // SyncCart with debounce
    on<SyncCart>(
      _onSyncCart,
      transformer: (events, mapper) {
        return events
            .debounceTime(const Duration(milliseconds: 2000))
            .asyncExpand(mapper);
      },
    );
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    final barId =
        event.barId ??
        (state is CartLoaded ? (state as CartLoaded).barId : null);

    if (state is CartLoaded) {
      final current = state as CartLoaded;
      if (current.cart.items.isNotEmpty && current.barId == barId) {
        return;
      }
    }

    CartLoaded currentState;
    if (state is CartLoaded) {
      currentState = state as CartLoaded;
    } else {
      currentState = CartLoaded(
        cart: CartModel(
          id: 0,
          userId: 0,
          items: [],
          totalItems: 0,
          subtotal: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        barId: barId,
      );
    }

    emit(currentState.copyWith(isLoading: true, barId: barId));

    final itemsInput = currentState.cart.items
        .map(
          (item) => CartItemInput(
            menuItemId: item.menuItemId,
            quantity: item.quantity,
          ),
        )
        .toList();

    final request = CartSyncRequest(
      items: itemsInput,
      activePromotionIds: currentState.selectedPromotionIds,
    );

    try {
      final result = await cartUsecase.syncCart(request);
      result.fold(
        (failure) =>
            emit(currentState.copyWith(isLoading: false, barId: barId)),
        (serverCart) => emit(CartLoaded(cart: serverCart, barId: barId)),
      );
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, barId: barId));
    }
  }

  Future<void> _onLoadCheckoutConfig(
    LoadCheckoutConfig event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;

      if (currentState.locationConfig != null &&
          currentState.barId == event.barId) {
        return;
      }

      final results = await Future.wait([
        barRepository.getLocationConfig(event.barId),
        barRepository.getPromotions(event.barId),
      ]);

      final locationResult = results[0] as Either<Failure, LocationConfig>;
      final promotionsResult =
          results[1] as Either<Failure, List<legacy_models.Promotion>>;

      LocationConfig? locationConfig = currentState.locationConfig;
      List<legacy_models.Promotion> promotions = currentState.activePromotions;

      locationResult.fold(
        (failure) => null,
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

  void _onAddToCart(AddToCart event, Emitter<CartState> emit) {
    CartLoaded currentState;

    if (state is CartLoaded) {
      currentState = state as CartLoaded;
    } else {
      currentState = CartLoaded(
        cart: CartModel(
          id: 0,
          userId: 0,
          items: [],
          totalItems: 0,
          subtotal: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    final switchedBar =
        currentState.barId != null &&
        currentState.barId != event.barId &&
        currentState.cart.items.isNotEmpty;

    final baseItems = switchedBar
        ? <CartItemModel>[]
        : List<CartItemModel>.from(currentState.cart.items);

    final existingIndex = baseItems.indexWhere(
      (item) => item.menuItemId == event.menuItemId,
    );

    List<CartItemModel> updatedItems;

    if (existingIndex != -1) {
      final existingItem = baseItems[existingIndex];
      final newQuantity = existingItem.quantity + event.quantity;
      updatedItems = List.from(baseItems);
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: newQuantity,
        totalPrice: newQuantity * existingItem.unitPrice,
      );
    } else {
      updatedItems = List.from(baseItems)
        ..add(
          CartItemModel(
            id: 0,
            cartId: currentState.cart.id,
            menuItemId: event.menuItemId,
            barId: event.barId,
            menuItemName: event.menuItemName,
            quantity: event.quantity,
            unitPrice: event.unitPrice,
            totalPrice: event.quantity * event.unitPrice,
          ),
        );
    }

    final updatedCart = currentState.cart.copyWith(
      items: updatedItems,
      totalItems: updatedItems.fold<int>(0, (sum, item) => sum + item.quantity),
      subtotal: updatedItems.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      ),
    );

    emit(currentState.copyWith(cart: updatedCart, barId: event.barId));
    add(SyncCart());
  }

  void _onUpdateCartItem(UpdateCartItem event, Emitter<CartState> emit) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;
    final currentItems = List<CartItemModel>.from(currentState.cart.items);
    final index = currentItems.indexWhere(
      (item) => item.menuItemId == event.menuItemId,
    );

    if (index != -1) {
      final item = currentItems[index];
      final updatedItem = item.copyWith(
        quantity: event.quantity,
        totalPrice: event.quantity * item.unitPrice,
      );
      currentItems[index] = updatedItem;

      final updatedCart = currentState.cart.copyWith(
        items: currentItems,
        totalItems: currentItems.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        ),
        subtotal: currentItems.fold<double>(
          0.0,
          (sum, item) => sum + item.totalPrice,
        ),
      );

      emit(currentState.copyWith(cart: updatedCart));
      add(SyncCart());
    }
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;
    final currentItems = currentState.cart.items
        .where((item) => item.menuItemId != event.menuItemId)
        .toList();

    final updatedCart = currentState.cart.copyWith(
      items: currentItems,
      totalItems: currentItems.fold<int>(0, (sum, item) => sum + item.quantity),
      subtotal: currentItems.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      ),
    );

    emit(currentState.copyWith(cart: updatedCart));
    add(SyncCart());
  }

  void _onDecreaseCartItem(DecreaseCartItem event, Emitter<CartState> emit) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;
    final currentItems = List<CartItemModel>.from(currentState.cart.items);
    final index = currentItems.indexWhere(
      (item) => item.menuItemId == event.menuItemId,
    );

    if (index == -1) return;

    final item = currentItems[index];
    if (item.quantity <= 1) {
      currentItems.removeAt(index);
    } else {
      currentItems[index] = item.copyWith(
        quantity: item.quantity - 1,
        totalPrice: (item.quantity - 1) * item.unitPrice,
      );
    }

    final updatedCart = currentState.cart.copyWith(
      items: currentItems,
      totalItems: currentItems.fold<int>(0, (sum, item) => sum + item.quantity),
      subtotal: currentItems.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      ),
    );

    emit(currentState.copyWith(cart: updatedCart));
    add(SyncCart());
  }

  void _onUpdateActivePromotions(
    UpdateActivePromotions event,
    Emitter<CartState> emit,
  ) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;

    emit(
      currentState.copyWith(
        selectedPromotionIds: event.activePromotionIds,
        isLoading: true,
      ),
    );
    add(SyncCart());
  }

  Future<void> _onSyncCart(SyncCart event, Emitter<CartState> emit) async {
    try {
      if (state is! CartLoaded) return;
      final currentState = state as CartLoaded;

      final itemsInput = currentState.cart.items
          .map(
            (item) => CartItemInput(
              menuItemId: item.menuItemId,
              quantity: item.quantity,
            ),
          )
          .toList();

      final request = CartSyncRequest(
        items: itemsInput,
        activePromotionIds: currentState.selectedPromotionIds,
      );

      final result = await cartUsecase.syncCart(request);

      result.fold(
        (failure) {
          if (state is CartLoaded) {
            emit((state as CartLoaded).copyWith(isLoading: false));
          }
        },
        (serverCart) {
          final latestState = state;
          if (latestState is! CartLoaded) return;
          emit(
            CartLoaded(
              cart: serverCart,
              barId: latestState.barId,
              locationConfig: latestState.locationConfig,
              activePromotions: latestState.activePromotions,
              selectedPromotionIds: latestState.selectedPromotionIds,
              spotAvailability: latestState.spotAvailability,
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in _onSyncCart: $e\n$stackTrace');
      }
      if (state is CartLoaded) {
        emit((state as CartLoaded).copyWith(isLoading: false));
      }
    }
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;

    // specific logic for clear cart: set items to empty and sync
    final updatedCart = currentState.cart.copyWith(
      items: [],
      totalItems: 0,
      subtotal: 0.0,
      discount: 0.0,
      total: 0.0,
      bundleSavings: 0.0,
      subtotalAfterBundles: 0.0,
      validationIssues: [],
    );

    emit(currentState.copyWith(cart: updatedCart, isLoading: true));
    add(SyncCart());
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

  Future<void> _onCheckSpotAvailability(
    CheckSpotAvailability event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;

    emit(currentState.copyWith(isLoading: true));

    final result = await cartUsecase.checkSpotAvailability(
      barId: event.barId,
      spotId: event.spotId,
    );

    result.fold((failure) => emit(CartError(message: failure.errorMessage)), (
      availability,
    ) {
      emit(
        currentState.copyWith(spotAvailability: availability, isLoading: false),
      );
    });
  }
}
