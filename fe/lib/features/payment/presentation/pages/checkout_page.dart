import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart'
    as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';

import '../../domain/models/payment_models.dart';
import '../widgets/brazil_payment_options.dart';
import '../widgets/checkout_order_summary.dart';
import '../widgets/digital_wallets_section.dart';
import '../widgets/pay_button.dart';
import '../widgets/saved_cards_section.dart';
import '../widgets/security_indicators.dart';

class CheckoutArguments {
  final List<CartItem> items;
  final double subtotal;
  final double total;
  final double bundleSavings;
  final Coupon? coupon;
  final String? locationIdentifier;
  final String? instructions;
  final List<String>? activePromotionIds;

  CheckoutArguments({
    required this.items,
    required this.subtotal,
    required this.total,
    required this.bundleSavings,
    this.coupon,
    this.locationIdentifier,
    this.instructions,
    this.activePromotionIds,
  });
}

class CheckoutPage extends StatefulWidget {
  final CheckoutArguments? arguments;

  const CheckoutPage({super.key, this.arguments});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? _selectedCardId = 'card-1';
  bool _isProcessing = false;

  // Mock saved cards for now
  final List<SavedCard> _savedCards = const [
    SavedCard(
      id: 'card-1',
      brand: CardBrand.mastercard,
      last4: '4242',
      expiry: '12/26',
    ),
    SavedCard(
      id: 'card-2',
      brand: CardBrand.visa,
      last4: '8888',
      expiry: '03/25',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.arguments == null) {
      return const Scaffold(body: Center(child: Text("No items in checkout")));
    }

    final args = widget.arguments!;
    final isDark = theme.brightness == Brightness.dark;

    // Map CartItems to OrderItems (Payment UI Model)
    final orderItems = args.items
        .map(
          (item) => OrderItem(
            name: item.name,
            quantity: item.quantity,
            price: item.price,
          ),
        )
        .toList();

    // Reconstruct OrderDiscount if coupon exists
    OrderDiscount? orderDiscount;
    if (args.coupon != null) {
      orderDiscount = OrderDiscount(
        amount: args.coupon!.discount,
        code: args.coupon!.code,
      );
    } else if (args.bundleSavings > 0) {
      // Display bundle savings as discount if no coupon
      orderDiscount = OrderDiscount(
        amount: args.bundleSavings,
        code: "BUNDLES",
      );
    }

    // Mock Cashback (5%)
    final cashback = args.total * 0.05;

    return BlocListener<CartBloc, CartState>(
      listener: _listenToCartState,
      child: Scaffold(
        backgroundColor: isDark ? barzDark : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      CheckoutOrderSummary(
                        items: orderItems,
                        subtotal: args.subtotal,
                        discount: orderDiscount,
                        cashback: cashback,
                        total: args.total,
                      ),
                      const SizedBox(height: 24),
                      SavedCardsSection(
                        cards: _savedCards,
                        selectedCardId: _selectedCardId,
                        onSelectCard: (id) =>
                            setState(() => _selectedCardId = id),
                        onAddCard: () {
                          // Mock
                        },
                      ),
                      const SizedBox(height: 24),
                      BrazilPaymentOptions(
                        onSelectPix: () {},
                        onSelectNubank: () {},
                        total: args.total,
                      ),
                      const SizedBox(height: 16),
                      DigitalWalletsSection(
                        onApplePay: () {},
                        onGooglePay: () {},
                      ),
                      const SecurityIndicators(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: (isDark ? barzDark : Colors.white).withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFDDDDDD),
              ),
            ),
          ),
          child: PayButton(
            total: args.total,
            isLoading: _isProcessing,
            onPressed: () => _handlePayment(context, args),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
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
            child: const Icon(Icons.credit_card, color: barzDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checkout',
                  style: TextStyle(
                    color: isDark ? textOnDark : textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Review & Pay',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePayment(BuildContext context, CheckoutArguments args) {
    setState(() => _isProcessing = true);

    // Trigger actual checkout
    context.read<CartBloc>().add(
      cart_event.Checkout(
        orderType: 'dine_in',
        paymentMethod: _selectedCardId ?? 'credit_card',
        tableNumber: args.locationIdentifier, // Passed from Cart
        specialInstructions: args.instructions,
        activePromotionIds: args.activePromotionIds,
      ),
    );
  }

  void _listenToCartState(BuildContext context, CartState state) {
    if (state is CheckoutSuccess) {
      if (mounted) setState(() => _isProcessing = false);
      _showOrderSuccessDialog(context, state.result.orderId);
    }
    if (state is CartError) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: errorRed),
      );
    }
  }

  void _showOrderSuccessDialog(BuildContext context, int orderId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 48, color: successGreen),
        title: Text(l10n.checkout_success),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.checkout_order_placed),
            Text(
              "Order #$orderId",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              AppRoute.goOrder(context, orderId);
            },
            child: Text(l10n.order_tracking),
          ),
        ],
      ),
    );
  }
}
