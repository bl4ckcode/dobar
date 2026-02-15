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
            .debounceTime(const Duration(milliseconds: 500))
            .asyncExpand(mapper);
      },
    );
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    // If already loaded, do not reset. This ensures the singleton state persists.
    if (state is CartLoaded) return;

    // Initialize with empty cart state instead of fetching from server
    // This prevents "items from other bars" from appearing and
    // strictly follows the Optimistic UI + Sync approach.
    emit(
      CartLoaded(
        cart: CartModel(
          id: 0,
          userId: 0,
          items: [],
          totalItems: 0,
          subtotal: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
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
    if (state is! CartLoaded) {
      add(LoadCart());
      return;
    }

    final currentState = state as CartLoaded;
    final currentItems = List<CartItemModel>.from(currentState.cart.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItemId == event.menuItemId,
    );

    List<CartItemModel> updatedItems;

    if (existingIndex != -1) {
      final existingItem = currentItems[existingIndex];
      final newQuantity = existingItem.quantity + event.quantity;
      updatedItems = List.from(currentItems);
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: newQuantity,
        totalPrice: newQuantity * existingItem.unitPrice,
      );
    } else {
      updatedItems = List.from(currentItems)
        ..add(
          CartItemModel(
            id: 0, // Temp ID
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

    emit(currentState.copyWith(cart: updatedCart, isLoading: true));
    add(SyncCart());
  }

  void _onUpdateCartItem(UpdateCartItem event, Emitter<CartState> emit) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;
    final currentItems = List<CartItemModel>.from(currentState.cart.items);
    final index = currentItems.indexWhere((item) => item.id == event.itemId);

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

      emit(currentState.copyWith(cart: updatedCart, isLoading: true));
      add(SyncCart());
    }
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    if (state is! CartLoaded) return;
    final currentState = state as CartLoaded;
    final currentItems = currentState.cart.items
        .where((item) => item.id != event.itemId)
        .toList();

    final updatedCart = currentState.cart.copyWith(
      items: currentItems,
      totalItems: currentItems.fold<int>(0, (sum, item) => sum + item.quantity),
      subtotal: currentItems.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      ),
    );

    emit(currentState.copyWith(cart: updatedCart, isLoading: true));
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
      var currentState = state as CartLoaded;

      // Construct request
      final itemsInput = currentState.cart.items
          .map(
            (item) => CartItemInput(
              menuItemId: item.menuItemId,
              quantity: item.quantity,
              // specialInstructions: item.specialInstructions // Not in CartItemModel yet?
            ),
          )
          .toList();

      final request = CartSyncRequest(
        items: itemsInput,
        // locationIdentifier: currentState.locationConfig.something?
        activePromotionIds: currentState.selectedPromotionIds,
      );

      final result = await cartUsecase.syncCart(request);

      result.fold(
        (failure) {
          emit(CartError(message: failure.errorMessage));
        },
        (cart) {
          emit(currentState.copyWith(cart: cart, isLoading: false));
        },
      );
    } catch (e, stackTrace) {
      // Catch-all for unexpected crashes during sync
      print('Error in _onSyncCart: $e\n$stackTrace');
      emit(CartError(message: 'Unexpected error syncing cart: $e'));
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
