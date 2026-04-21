import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart'
    as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/payment/presentation/pages/checkout_page.dart'; // For CheckoutArguments
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart'
    as checkin_event;
import 'package:barz/features/checkin/presentation/bloc/checkin_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/coupon_input_section.dart';
import '../widgets/active_promotions_section.dart';
import '../widgets/order_summary_section.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/theme/theme_cubit.dart';

class CartPage extends StatefulWidget {
  final int? barId;
  final bool showBackButton;

  const CartPage({super.key, this.barId, this.showBackButton = true});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    getItInjector<CartBloc>().add(cart_event.LoadCart(barId: widget.barId));
    getItInjector<CheckinBloc>().add(const checkin_event.LoadActiveCheckin());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getItInjector<CartBloc>()),
        BlocProvider.value(value: getItInjector<CheckinBloc>()),
      ],
      child: _CartPageContent(
        showBackButton: widget.showBackButton,
        barId: widget.barId,
      ),
    );
  }
}

class _CartPageContent extends StatefulWidget {
  final bool showBackButton;
  final int? barId;
  const _CartPageContent({required this.showBackButton, this.barId});

  @override
  State<_CartPageContent> createState() => _CartPageContentState();
}

class _CartPageContentState extends State<_CartPageContent> {
  final _tableController = TextEditingController();
  final _locationNoteController =
      TextEditingController(); // For free text location
  final _instructionsController = TextEditingController();

  // Configuration is loaded from backend via CartBloc
  String? _selectedSpotId;
  int _tableNumber = 0;

  int? _lastLoadedBarId;
  bool _isCheckoutPending = false;
  bool _isSummaryExpanded = false;

  @override
  void dispose() {
    _tableController.dispose();
    _locationNoteController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _updateTableNumber(int delta) {
    setState(() {
      _tableNumber = (_tableNumber + delta).clamp(0, 999);
      _tableController.text = _tableNumber > 0 ? _tableNumber.toString() : '';
    });
  }

  CartModel? _lastLoadedCart;

  void _listenToCartState(BuildContext context, CartState state) {
    if (state is CartLoaded) {
      _lastLoadedCart = state.cart;
    }

    if (state is CartError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: errorRed),
      );
    }

    // Load config if needed
    if (state is CartLoaded &&
        state.cart.items.isNotEmpty &&
        state.barId != null &&
        (state.locationConfig == null || _lastLoadedBarId != state.barId)) {
      final barId = state.barId!;
      _lastLoadedBarId = barId;
      context.read<CartBloc>().add(cart_event.LoadCheckoutConfig(barId: barId));
    }

    // Handle Spot Availability Check
    if (state is CartLoaded &&
        state.spotAvailability != null &&
        _isCheckoutPending) {
      if (state.spotAvailability!.isAvailable) {
        _isCheckoutPending = false;
        // Proceed to checkout
        _proceedToCheckout(
          context,
          state.cart,
          _selectedSpotId,
        ); // Use selected spot ID
      } else {
        _isCheckoutPending = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.spotAvailability!.message ??
                  AppLocalizations.of(context)!.cart_spot_not_available,
            ),
            backgroundColor: errorRed,
          ),
        );
      }
    }
  }

  void _handleCheckout(BuildContext context) {
    final state = context.read<CartBloc>().state;
    if (state is! CartLoaded) return;

    final locationConfig = state.locationConfig;
    final method = locationConfig?.method ?? LocationMethod.tableNumber;

    // Determine location identifier based on method
    String? locationIdentifier;
    if (method == LocationMethod.tableNumber) {
      locationIdentifier = _tableController.text;
    } else if (method == LocationMethod.spotList) {
      locationIdentifier = _selectedSpotId;

      // Check availability for spot
      if (locationIdentifier != null) {
        context.read<CartBloc>().add(
          cart_event.CheckSpotAvailability(
            barId: state.barId ?? 0,
            spotId: locationIdentifier,
          ),
        );
        _isCheckoutPending = true;
        return;
      }
    } else {
      locationIdentifier = _locationNoteController.text;
    }

    _proceedToCheckout(context, state.cart, locationIdentifier);
  }

  void _proceedToCheckout(
    BuildContext context,
    CartModel cart,
    String? locationIdentifier,
  ) {
    final items = cart.items
        .map(
          (item) => CartItem(
            id: item.id.toString(),
            name: item.menuItemName,
            description: '',
            price: item.unitPrice,
            quantity: item.quantity,
          ),
        )
        .toList();

    Coupon? coupon;
    if (cart.appliedBundles.isNotEmpty) {
      coupon = Coupon(
        // Assumes Coupon is available from imports
        code: cart.appliedBundles.first.bundleName,
        discount: cart.appliedBundles.first.discountAmount,
        type: CouponType.fixed,
      );
    }

    final args = CheckoutArguments(
      items: items,
      subtotal: cart.subtotal,
      total: cart.total,
      bundleSavings: cart.bundleSavings,
      coupon: coupon,
      locationIdentifier: locationIdentifier,
      instructions: _instructionsController.text.isNotEmpty
          ? _instructionsController.text
          : null,
      activePromotionIds: (context.read<CartBloc>().state is CartLoaded)
          ? (context.read<CartBloc>().state as CartLoaded).selectedPromotionIds
          : [],
    );

    context.push(AppRoute.checkout.path, extra: args);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? barzDark : Colors.white,
      body: BlocListener<CartBloc, CartState>(
        listener: _listenToCartState,
        child: BlocBuilder<CheckinBloc, CheckinState>(
          builder: (context, checkinState) {
            // Auto-fill table number (logic omitted for brevity, keeping existing)
            if (checkinState.isCheckedIn &&
                checkinState.activeCheckin?.tableNumber != null &&
                _tableController.text.isEmpty &&
                _tableNumber == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _tableNumber == 0) {
                  final tVal =
                      int.tryParse(checkinState.activeCheckin!.tableNumber!) ??
                      0;
                  if (tVal > 0) {
                    setState(() {
                      _tableNumber = tVal;
                      _tableController.text = tVal.toString();
                    });
                  }
                }
              });
            }

            return BlocBuilder<CartBloc, CartState>(
              builder: (context, state) {
                if (state is CartLoaded) {
                  _lastLoadedCart = state.cart;
                }

                final cart = _lastLoadedCart;
                final items = cart?.items ?? [];

                if (state is CartLoading && cart == null) {
                  return const BarzLoadingWidget();
                }

                if (cart != null && items.isEmpty) {
                  return _buildEmptyState(
                    context,
                    isDark,
                    widget.showBackButton,
                  );
                }

                final bool isLoading = (state is CartLoaded)
                    ? state.isLoading
                    : false;

                // Map legacy items to new UI items
                final uiItems = items
                    .map(
                      (item) => CartItem(
                        id: item.menuItemId.toString(),
                        name: item.menuItemName,
                        description: 'Delicious item',
                        price: item.unitPrice,
                        quantity: item.quantity,
                        imageUrl: null,
                      ),
                    )
                    .toList();

                // Map Bundle/Coupon
                Coupon? displayedCoupon;
                if (cart != null && cart.appliedBundles.isNotEmpty) {
                  final bundle = cart.appliedBundles.first;
                  displayedCoupon = Coupon(
                    code: bundle.bundleName,
                    discount: bundle.discountAmount,
                    type: CouponType.fixed,
                  );
                }

                return Stack(
                  children: [
                    SafeArea(
                      child: Column(
                        children: [
                          // Fixed Header
                          _buildHeader(
                            context,
                            isDark,
                            items.length,
                            widget.showBackButton,
                          ),

                          // Scrollable Content
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 140),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  // Cart Items
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: uiItems.length,
                                    itemBuilder: (context, index) {
                                      final item = uiItems[index];
                                      return CartItemCard(
                                        key: ValueKey(item.id),
                                        item: item,
                                        onQuantityChanged: (qty) {
                                          final menuItemId = int.parse(item.id);
                                          if (qty < 1) {
                                            context.read<CartBloc>().add(
                                              cart_event.RemoveFromCart(
                                                menuItemId: menuItemId,
                                              ),
                                            );
                                          } else {
                                            context.read<CartBloc>().add(
                                              cart_event.UpdateCartItem(
                                                menuItemId: menuItemId,
                                                quantity: qty,
                                              ),
                                            );
                                          }
                                        },
                                        onRemove: () =>
                                            context.read<CartBloc>().add(
                                              cart_event.RemoveFromCart(
                                                menuItemId: int.parse(item.id),
                                              ),
                                            ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Coupon Section
                                  CouponInputSection(
                                    appliedCoupon: displayedCoupon,
                                    onApplyCoupon: (code) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.cart_coupon_not_connected,
                                          ),
                                        ),
                                      );
                                      return false;
                                    },
                                    onRemoveCoupon: () {},
                                  ),

                                  const SizedBox(height: 16),

                                  // Active Promotions Section
                                  if (state is CartLoaded &&
                                      state.activePromotions.isNotEmpty) ...[
                                    ActivePromotionsSection(
                                      promotions: state.activePromotions,
                                      selectedIds: state.selectedPromotionIds
                                          .toSet(),
                                      onToggle: (id, isActive) {
                                        final currentIds = state
                                            .selectedPromotionIds
                                            .toSet();
                                        if (isActive) {
                                          currentIds.add(id);
                                        } else {
                                          currentIds.remove(id);
                                        }
                                        context.read<CartBloc>().add(
                                          cart_event.UpdateActivePromotions(
                                            activePromotionIds: currentIds
                                                .toList(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  const SizedBox(height: 16),

                                  // Where Are You Section
                                  _buildWhereAreYouSection(context, isDark),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sticky Bottom Sheet for Order Summary
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: OrderSummarySection(
                        items: uiItems,
                        coupon: displayedCoupon,
                        promotions: (state is CartLoaded)
                            ? state.activePromotions
                            : const [],
                        overrideTotal: cart?.total,
                        overrideDiscount: (cart != null && cart.discount > 0)
                            ? cart.discount
                            : null,
                        onCheckout: () => _handleCheckout(context),
                        isLoading: isLoading,
                        isExpanded: _isSummaryExpanded,
                        onToggle: () {
                          setState(() {
                            _isSummaryExpanded = !_isSummaryExpanded;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    int itemCount,
    bool showBack,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (showBack && context.canPop()) ...[
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? barzDarkLight : surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDark ? textOnDark : textPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: barzGold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: barzDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cart_title,
                  style: TextStyle(
                    color: isDark ? textOnDark : textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.cart_items(itemCount),
                  style: TextStyle(
                    color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.read<ThemeCubit>().toggleTheme(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? barzDarkLight : surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: isDark ? barzGold : barzDark,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool showBack) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: isDark
                ? const Color(0xFF444444)
                : textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.cart_empty,
            style: TextStyle(
              color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
              fontSize: 16,
            ),
          ),
          if (showBack && widget.barId != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    AppRoute.home.go(context);
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.cart_go_back),
                style: FilledButton.styleFrom(
                  backgroundColor: barzGold,
                  foregroundColor: barzDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWhereAreYouSection(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? barzDarkLight : surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: isDark ? textOnDark : textPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.cart_location_question,
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location Logic driven by Bloc State
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              final config = (state is CartLoaded)
                  ? state.locationConfig
                  : null;
              final method = config?.method ?? LocationMethod.tableNumber;

              if (method == LocationMethod.tableNumber) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? barzDark : surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildSpinnerButton(
                        icon: Icons.remove,
                        onTap: () => _updateTableNumber(-1),
                        isDark: isDark,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _tableController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? textOnDark : textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: l10n.cart_table_number_hint,
                            hintStyle: TextStyle(
                              color: isDark ? textTertiary : textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _tableNumber = int.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ),
                      _buildSpinnerButton(
                        icon: Icons.add,
                        onTap: () => _updateTableNumber(1),
                        isDark: isDark,
                      ),
                    ],
                  ),
                );
              } else if (method == LocationMethod.spotList) {
                final spots = config?.spots ?? [];
                // Ensure selected spot is valid
                if (_selectedSpotId != null &&
                    !spots.any((s) => s.id == _selectedSpotId)) {
                  // reset if invalid, but wrapped in microtask to avoid build error?
                  // actually let's just ignore for now or handle in onChanged
                }

                return DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedSpotId,
                  items: spots
                      .map(
                        (spot) => DropdownMenuItem(
                          value: spot.id,
                          child: Text(spot.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedSpotId = val);
                  },
                  dropdownColor: isDark ? barzDarkLight : surfaceWhite,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? barzDark : surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.place),
                    hintText: l10n.cart_select_location,
                  ),
                );
              } else {
                return TextField(
                  controller: _locationNoteController,
                  decoration: InputDecoration(
                    labelText: l10n.cart_location_label,
                    hintText: l10n.cart_location_hint,
                    filled: true,
                    fillColor: isDark ? barzDark : surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.pin_drop),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 16),
          Divider(color: isDark ? barzDarkMuted : surfaceDim),
          const SizedBox(height: 16),

          // Special Instructions
          TextField(
            controller: _instructionsController,
            decoration: InputDecoration(
              labelText: l10n.cart_notes_label,
              hintText: l10n.cart_notes_hint,
              filled: true,
              fillColor: isDark ? barzDark : surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.comment),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSpinnerButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? barzDarkCard : surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: isDark ? textOnDark : textPrimary),
      ),
    );
  }
}
