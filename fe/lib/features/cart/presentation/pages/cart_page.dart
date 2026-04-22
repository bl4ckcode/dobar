import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart'
    as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/payments/presentation/pages/checkout_page.dart'; // For CheckoutArguments
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
  final _locationNoteController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _selectedSpotId;
  int _tableNumber = 0;
  int? _lastLoadedBarId;
  bool _isCheckoutPending = false;
  CartModel? _lastLoadedCart;

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

  void _listenToCartState(BuildContext context, CartState state) {
    if (state is CartLoaded) {
      _lastLoadedCart = state.cart;
    }

    if (state is CartError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: errorRed),
      );
    }

    if (state is CartLoaded &&
        state.cart.items.isNotEmpty &&
        state.barId != null &&
        (state.locationConfig == null || _lastLoadedBarId != state.barId)) {
      final barId = state.barId!;
      _lastLoadedBarId = barId;
      context.read<CartBloc>().add(cart_event.LoadCheckoutConfig(barId: barId));
    }

    if (state is CartLoaded &&
        state.spotAvailability != null &&
        _isCheckoutPending) {
      if (state.spotAvailability!.isAvailable) {
        _isCheckoutPending = false;
        _proceedToCheckout(
          context,
          state.cart,
          _selectedSpotId,
        );
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

    String? locationIdentifier;
    if (method == LocationMethod.tableNumber) {
      locationIdentifier = _tableController.text;
    } else if (method == LocationMethod.spotList) {
      locationIdentifier = _selectedSpotId;
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
                return state.maybeWhen(
                  loading: () => (_lastLoadedCart == null)
                      ? const BarzLoadingWidget()
                      : _buildCartStack(context, state, isDark, l10n),
                  loaded: (cart,
                      barId,
                      locationConfig,
                      activePromotions,
                      selectedPromotionIds,
                      spotAvailability,
                      isLoading,
                      version,
                      lastSyncTimestamp) {
                    _lastLoadedCart = cart;
                    if (cart.items.isEmpty) {
                      return _buildEmptyState(
                        context,
                        isDark,
                        widget.showBackButton,
                      );
                    }
                    return _buildCartStack(context, state, isDark, l10n);
                  },
                  checkoutSuccess: (_) {
                    _lastLoadedCart = null;
                    return _buildEmptyState(
                      context,
                      isDark,
                      widget.showBackButton,
                    );
                  },
                  orElse: () => (_lastLoadedCart != null &&
                          _lastLoadedCart!.items.isNotEmpty)
                      ? _buildCartStack(context, state, isDark, l10n)
                      : _buildEmptyState(
                          context,
                          isDark,
                          widget.showBackButton,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartStack(
    BuildContext context,
    CartState state,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final cart = _lastLoadedCart!;

    Coupon? displayedCoupon;
    if (cart.appliedBundles.isNotEmpty) {
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
              BlocSelector<CartBloc, CartState, int>(
                selector: (state) => state.maybeWhen(
                  loaded: (cart, barId, locationConfig, activePromotions,
                          selectedPromotionIds, spotAvailability, isLoading,
                          version, lastSyncTimestamp) =>
                      cart.items.length,
                  orElse: () => _lastLoadedCart?.items.length ?? 0,
                ),
                builder: (context, itemCount) {
                  return _buildHeader(
                    context,
                    isDark,
                    itemCount,
                    widget.showBackButton,
                  );
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 320),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const _CartItemsList(),
                      const SizedBox(height: 16),
                      CouponInputSection(
                        appliedCoupon: displayedCoupon,
                        onApplyCoupon: (code) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.cart_coupon_not_connected),
                            ),
                          );
                          return false;
                        },
                        onRemoveCoupon: () {},
                      ),
                      const SizedBox(height: 16),
                      const _ActivePromotions(),
                      const SizedBox(height: 16),
                      _buildWhereAreYouSection(context, isDark),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const _CartSummary(),
      ],
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
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              final config = (state is CartLoaded) ? state.locationConfig : null;
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
                return DropdownButtonFormField<String>(
                  initialValue: _selectedSpotId,
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

class _CartItemsList extends StatelessWidget {
  const _CartItemsList();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartBloc, CartState, List<CartItemModel>>(
      selector: (state) => state.maybeWhen(
        loaded: (cart, barId, locationConfig, activePromotions,
                selectedPromotionIds, spotAvailability, isLoading, version,
                lastSyncTimestamp) =>
            cart.items,
        orElse: () => [],
      ),
      builder: (context, items) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final uiItem = CartItem(
              id: item.menuItemId.toString(),
              name: item.menuItemName,
              description: '',
              price: item.unitPrice,
              quantity: item.quantity,
              imageUrl: null,
            );
            return CartItemCard(
              key: ValueKey(uiItem.id),
              item: uiItem,
              onQuantityChanged: (qty) {
                final menuItemId = int.parse(uiItem.id);
                if (qty < 1) {
                  context.read<CartBloc>().add(
                        cart_event.RemoveFromCart(menuItemId: menuItemId),
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
              onRemove: () => context.read<CartBloc>().add(
                    cart_event.RemoveFromCart(
                      menuItemId: int.parse(uiItem.id),
                    ),
                  ),
            );
          },
        );
      },
    );
  }
}

class _ActivePromotions extends StatelessWidget {
  const _ActivePromotions();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartBloc, CartState,
        ({List<Promotion> list, List<String> selected})>(
      selector: (state) => state.maybeWhen(
        loaded: (cart, barId, locationConfig, activePromotions,
                selectedPromotionIds, spotAvailability, isLoading, version,
                lastSyncTimestamp) =>
            (list: activePromotions, selected: selectedPromotionIds),
        orElse: () => (list: [], selected: []),
      ),
      builder: (context, data) {
        if (data.list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            ActivePromotionsSection(
              promotions: data.list,
              selectedIds: data.selected.toSet(),
              onToggle: (id, isActive) {
                final currentIds = data.selected.toSet();
                if (isActive) {
                  currentIds.add(id);
                } else {
                  currentIds.remove(id);
                }
                context.read<CartBloc>().add(
                      cart_event.UpdateActivePromotions(
                        activePromotionIds: currentIds.toList(),
                      ),
                    );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _CartSummary extends StatefulWidget {
  const _CartSummary();

  @override
  State<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends State<_CartSummary> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      buildWhen: (prev, curr) {
        if (prev is! CartLoaded || curr is! CartLoaded) return true;
        return prev.cart.total != curr.cart.total ||
            prev.cart.discount != curr.cart.discount ||
            prev.isLoading != curr.isLoading ||
            prev.cart.items.length != curr.cart.items.length;
      },
      builder: (context, state) {
        if (state is! CartLoaded) return const SizedBox.shrink();

        final cart = state.cart;
        final items = cart.items;
        final uiItems = items
            .map(
              (item) => CartItem(
                id: item.menuItemId.toString(),
                name: item.menuItemName,
                description: '',
                price: item.unitPrice,
                quantity: item.quantity,
                imageUrl: null,
              ),
            )
            .toList();

        Coupon? displayedCoupon;
        if (cart.appliedBundles.isNotEmpty) {
          final bundle = cart.appliedBundles.first;
          displayedCoupon = Coupon(
            code: bundle.bundleName,
            discount: bundle.discountAmount,
            type: CouponType.fixed,
          );
        }

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: OrderSummarySection(
            items: uiItems,
            coupon: displayedCoupon,
            promotions: state.activePromotions,
            overrideTotal: cart.total,
            overrideDiscount: cart.discount > 0 ? cart.discount : null,
            onCheckout: () {
              final state = context.findAncestorStateOfType<_CartPageContentState>();
              state?._handleCheckout(context);
            },
            isLoading: state.isLoading,
            isExpanded: _isExpanded,
            onToggle: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
        );
      },
    );
  }
}
