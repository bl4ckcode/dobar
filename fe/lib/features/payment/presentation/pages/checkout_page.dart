import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart'
    as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/payment/domain/models/payment_models.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/bloc/payment_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/user/presentation/bloc/user_bloc.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/features/payments/domain/models/transaction.dart';
import 'package:barz/features/user/domain/models/user_document.dart';

import '../widgets/checkout_order_summary.dart';
import '../widgets/pay_button.dart';
import '../widgets/payment_methods_card.dart';
import '../widgets/payment_options_grid.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import '../widgets/security_indicators.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';

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
  String? _selectedCardId;
  bool _isProcessing = false;

  SavedCard _fromPaymentMethod(PaymentMethod m) {
    CardBrand brand = CardBrand.visa;
    final rawBrand = (m.brand ?? '').toLowerCase();
    if (rawBrand.contains('master')) brand = CardBrand.mastercard;
    if (rawBrand.contains('elo')) brand = CardBrand.elo;
    if (rawBrand.contains('amex')) brand = CardBrand.amex;

    final expMonth = m.expiryMonth ?? 0;
    final expYear = m.expiryYear ?? 0;
    
    final monthStr = expMonth.toString().padLeft(2, '0');
    final yearFullStr = expYear.toString().padLeft(2, '0');
    final yearStr = yearFullStr.length >= 2 
        ? yearFullStr.substring(yearFullStr.length - 2) 
        : yearFullStr;
        
    final expiry = '$monthStr/$yearStr';

    return SavedCard(
      id: m.id?.toString() ?? '',
      brand: brand,
      last4: m.lastFourDigits ?? '',
      expiry: expiry,
    );
  }

  void _onAddCardComplete(Map<String, String> cardData) {
    final brand = cardData['brand'] ?? 'visa';
    final lastFour = cardData['last4'] ?? '';
    final expParts = (cardData['expiry'] ?? '').split('/');
    final expMonth = int.tryParse(expParts.isNotEmpty ? expParts[0] : '') ?? 0;
    final expYear = int.tryParse(expParts.length > 1 ? expParts[1] : '') ?? 0;
    final token = cardData['token'] ?? '';

    context.read<PaymentBloc>().add(
      AddSavedCard(
        cardToken: token,
        lastFour: lastFour,
        brand: brand,
        expMonth: expMonth,
        expYear: expYear.toString().length == 2 ? 2000 + expYear : expYear,
        isDefault: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (widget.arguments == null) {
      return Scaffold(body: Center(child: Text(l10n.error_generic)));
    }

    final args = widget.arguments!;
    final isDark = theme.brightness == Brightness.dark;

    final orderItems = args.items
        .map(
          (item) => OrderItem(
            name: item.name,
            quantity: item.quantity,
            price: item.price,
          ),
        )
        .toList();

    OrderDiscount? orderDiscount;
    if (args.coupon != null) {
      orderDiscount = OrderDiscount(
        amount: args.coupon!.discount,
        code: args.coupon!.code,
      );
    } else if (args.bundleSavings > 0) {
      orderDiscount = OrderDiscount(
        amount: args.bundleSavings,
        code: 'BUNDLES',
      );
    }

    final userState = context.read<UserBloc>().state;
    final isPro = userState.user?.isPro ?? false;
    final cashback = args.total * (isPro ? 0.10 : 0.05);

    return MultiBlocListener(
      listeners: [
        BlocListener<CartBloc, CartState>(listener: _listenToCartState),
        BlocListener<PaymentBloc, PaymentState>(listener: _listenToPaymentState),
      ],
      child: Scaffold(
        backgroundColor: isDark ? barzDark : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, l10n, isDark),
              Expanded(
                child: BlocBuilder<PaymentBloc, PaymentState>(
                  builder: (context, paymentState) {
                    final savedCards = paymentState.savedCards
                        .map(_fromPaymentMethod)
                        .toList();

                    if (_selectedCardId == null && savedCards.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _selectedCardId = savedCards.first.id);
                        }
                      });
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          CheckoutOrderSummary(
                                items: orderItems,
                                subtotal: args.subtotal,
                                discount: orderDiscount,
                                cashback: cashback,
                                total: args.total,
                                isPro: isPro,
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 32),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              l10n.payment_methods_title,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          PaymentMethodsCard(
                            savedCards: savedCards,
                            selectedCardId: _selectedCardId,
                            onSelectCard: (id) =>
                                setState(() => _selectedCardId = id),
                            onAddCardComplete: _onAddCardComplete,
                            paymentOptions: [
                              PaymentOptionItem(
                                label: l10n.payment_method_pix,
                                icon: LucideIcons.qrCode,
                                iconColor: const Color(0xFF32BCAD),
                                onTap: () =>
                                    setState(() => _selectedCardId = '__pix__'),
                              ),
                              PaymentOptionItem(
                                label: 'Nubank Pay',
                                icon: LucideIcons.wallet,
                                iconColor: const Color(0xFF8A05BE),
                                onTap: () => setState(
                                  () => _selectedCardId = '__nubank__',
                                ),
                              ),
                            ],
                            onApplePay: () =>
                                setState(() => _selectedCardId = '__apple__'),
                            onGooglePay: () =>
                                setState(() => _selectedCardId = '__google__'),
                            isDark: isDark,
                            isLoadingCards: paymentState.isLoading,
                          ).animate().fadeIn(delay: 200.ms),

                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: SecurityIndicators(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? context.dobarColors.background : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
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

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final colors = context.dobarColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          _CircleIconButton(
            onPressed: () => context.pop(),
            icon: LucideIcons.chevronLeft,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.payment_title,
                  style: GoogleFonts.spaceGrotesk(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.checkout_order_details,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.labelSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _CircleIconButton(
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
            icon: isDark ? LucideIcons.sun : LucideIcons.moon,
            isDark: isDark,
            iconColor: isDark ? colors.buttonPrimary : null,
          ),
        ],
      ),
    );
  }

  void _handlePayment(BuildContext context, CheckoutArguments args) {
    setState(() => _isProcessing = true);

    context.read<CartBloc>().add(
      cart_event.Checkout(
        orderType: 'dine_in',
        paymentMethod: _selectedCardId ?? 'credit_card',
        tableNumber: args.locationIdentifier,
        specialInstructions: args.instructions,
        activePromotionIds: args.activePromotionIds,
      ),
    );
  }

  void _listenToCartState(BuildContext context, CartState state) {
    if (state is CheckoutSuccess) {
      // Order created successfully, now trigger payment
      final userState = context.read<UserBloc>().state;
      final user = userState.user;

      if (user == null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found. Please log in again.')),
        );
        return;
      }

      final barId = (context.read<CartBloc>().state as CartLoaded).barId ?? 0;
      
      String? documentNumber;
      if (user.documents.isNotEmpty) {
        final doc = user.documents.firstWhere(
          (d) => d.type == DocumentType.cpf,
          orElse: () => user.documents.first,
        );
        documentNumber = doc.number;
      }

      if (documentNumber == null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add your CPF/CNPJ in profile settings before paying.')),
        );
        return;
      }

      final customerInfo = CustomerInfo(
        name: user.displayName ?? '',
        email: user.email ?? '',
        document: documentNumber,
        phone: user.phoneNumber,
      );

      final paymentType = _selectedCardId?.startsWith('__pix__') == true
          ? PaymentType.pix
          : PaymentType.credit;

      final request = PaymentRequest(
        orderId: state.result.orderId,
        barId: barId,
        amount: state.result.total,
        paymentType: paymentType,
        paymentMethodId: paymentType == PaymentType.credit && _selectedCardId != null && !_selectedCardId!.startsWith('__')
            ? int.tryParse(_selectedCardId!)
            : null,
        cardToken: null, // If adding card, token is handled elsewhere
        customerInfo: customerInfo,
        provider: _selectedCardId?.contains('apple') == true
            ? 'apple_pay'
            : (_selectedCardId?.contains('google') == true ? 'google_pay' : null),
      );

      if (paymentType == PaymentType.pix) {
        context.read<PaymentBloc>().add(InitiatePixPayment(request));
      } else {
        context.read<PaymentBloc>().add(ProcessPayment(request));
      }
    }
    if (state is CartError) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
      );
    }
  }

  void _listenToPaymentState(BuildContext context, PaymentState state) {
    if (state.currentTransaction != null && state.currentTransaction!.status == TransactionStatus.approved) {
      if (mounted) setState(() => _isProcessing = false);
      
      // Clear cart on success FIRST
      context.read<CartBloc>().add(cart_event.ClearCart());
      
      // Then navigate to tracking page
      final orderId = state.currentTransaction!.orderId ?? 0;
      AppRoute.goOrder(context, orderId);
    } else if (state.pixPayment != null) {
      if (mounted) setState(() => _isProcessing = false);
      
      // Clear cart for PIX
      context.read<CartBloc>().add(cart_event.ClearCart());

      final cartState = context.read<CartBloc>().state;
      if (cartState is CheckoutSuccess) {
        AppRoute.goOrder(context, cartState.result.orderId);
      }
    } else if (state.error != null) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

}

class _CircleIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final bool isDark;
  final Color? iconColor;

  const _CircleIconButton({
    required this.onPressed,
    required this.icon,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: colors.surface.withValues(alpha: 0.1)),
        ),
        child: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.white : Colors.black),
          size: 20,
        ),
      ),
    );
  }
}
