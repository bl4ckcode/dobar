import 'package:barz/features/checkin/presentation/checkin_gate.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/cart/domain/models/cart_model.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart'
    as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/payments/domain/models/checkout_models.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/payments/presentation/bloc/payment_state.dart';
import 'package:barz/features/payments/presentation/widgets/pix_payment_modal.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/user/presentation/bloc/user_bloc.dart';
import 'package:barz/features/user/presentation/bloc/user_event.dart';
import 'package:barz/features/payments/domain/models/payment_model.dart';
import 'package:barz/core/utils/idempotency.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/presentation/bloc/user_state.dart';

import 'dart:async';
import '../widgets/checkout_order_summary.dart';
import '../widgets/pay_button.dart';
import '../widgets/payment_methods_card.dart';
import '../widgets/payment_options_grid.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import '../widgets/security_indicators.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/router/route_arguments.dart';

class CheckoutArguments {
  final List<CartItem> items;
  final double subtotal;
  final double total;
  final double bundleSavings;
  final Coupon? coupon;
  final String? locationIdentifier;
  final String? instructions;
  final List<String>? activePromotionIds;
  final CheckoutResult? pendingResult;

  CheckoutArguments({
    required this.items,
    required this.subtotal,
    required this.total,
    required this.bundleSavings,
    this.coupon,
    this.locationIdentifier,
    this.instructions,
    this.activePromotionIds,
    this.pendingResult,
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
  bool _isWaitingForProfile = false;
  bool _isOpeningRegistration = false;
  bool _isWaitingForDocument = false;
  int? _cachedBarId;
  CheckoutResult? _checkoutResult;
  String? _paymentAttemptKey;
  bool _pixModalOpen = false;
  String? _pollingPaymentId;
  bool _resumePaymentAfterDocument = true;
  Timer? _pixPollTimer;
  int _pixPollCount = 0;
  PixPaymentResponse? _currentPixPayment;
  int? _currentPixOrderId;

  @override
  void initState() {
    super.initState();
    _checkoutResult = widget.arguments?.pendingResult;
    _cachedBarId = _checkoutResult?.barId;
    _paymentAttemptKey = _checkoutResult?.paymentAttemptKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserBloc>().add(const UserEvent.loadCurrentUser());
      }
    });
  }

  Future<bool> _beforeAddCard() async {
    final user = context.read<UserBloc>().state.user;
    if (user == null) {
      context.read<UserBloc>().add(const UserEvent.loadCurrentUser());
      return false;
    }
    if (!user.hasCompletedRegistration) {
      await _openCompleteRegistration(user);
      return false;
    }
    if (!user.documents.any(
      (doc) => doc.type == DocumentType.cpf && doc.number.trim().isNotEmpty,
    )) {
      _resumePaymentAfterDocument = false;
      _showCpfPrompt(context, user);
      return false;
    }
    return true;
  }

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
    final token = cardData['token'];
    if (token == null || !token.startsWith('token_')) return;

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
        BlocListener<PaymentBloc, PaymentState>(
          listener: _listenToPaymentState,
        ),
        BlocListener<UserBloc, UserState>(
          listener: (context, state) {
            if (_isWaitingForProfile &&
                !state.isLoading &&
                state.error == null &&
                state.user != null) {
              setState(() => _isWaitingForProfile = false);
              if (state.user!.hasCompletedRegistration) {
                _handlePayment(context, widget.arguments!);
              } else {
                _openCompleteRegistration(state.user!);
              }
            } else if (_isWaitingForDocument && state.user != null) {
              final user = state.user!;
              final hasCpf = user.documents.any(
                (d) => d.type == DocumentType.cpf,
              );
              if (hasCpf && !state.isUpdating) {
                setState(() => _isWaitingForDocument = false);
                if (_resumePaymentAfterDocument) {
                  _handlePayment(context, widget.arguments!);
                }
              }
            }
            if (state.error != null &&
                !state.isLoading &&
                !state.isUpdating &&
                (_isWaitingForDocument || _isWaitingForProfile)) {
              setState(() {
                _isWaitingForDocument = false;
                _isWaitingForProfile = false;
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
        ),
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
                        .where((card) => card.isUsable)
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
                            beforeAddCard: _beforeAddCard,
                            paymentOptions: [
                              PaymentOptionItem(
                                label: l10n.payment_method_pix,
                                icon: LucideIcons.qr_code,
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
            total: widget.arguments?.total ?? 0,
            isLoading:
                _isProcessing || _isWaitingForProfile || _isOpeningRegistration,
            loadingLabel: _isWaitingForProfile
                ? l10n.payment_loading_profile
                : null,
            onPressed: () => _handlePayment(context, widget.arguments!),
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
            icon: LucideIcons.chevron_left,
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

  Future<void> _handlePayment(
    BuildContext context,
    CheckoutArguments args,
  ) async {
    if (_isProcessing || _isWaitingForProfile || _isOpeningRegistration) {
      return;
    }

    final userState = context.read<UserBloc>().state;
    if (userState.user == null) {
      setState(() => _isWaitingForProfile = true);
      context.read<UserBloc>().add(const UserEvent.loadCurrentUser());
      return;
    }

    if (!userState.user!.hasCompletedRegistration) {
      _openCompleteRegistration(userState.user!);
      return;
    }

    if (_selectedCardId != '__pix__' &&
        int.tryParse(_selectedCardId ?? '') == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.payment_select_method),
        ),
      );
      return;
    }
    if (!userState.user!.documents.any(
      (doc) => doc.type == DocumentType.cpf && doc.number.trim().isNotEmpty,
    )) {
      _resumePaymentAfterDocument = true;
      _showCpfPrompt(context, userState.user!);
      return;
    }
    final cartState = context.read<CartBloc>().state;
    final venue =
        _checkoutResult?.barId ??
        (cartState is CheckoutSuccess
            ? cartState.result.barId
            : cartState is CartLoaded
            ? cartState.barId
            : _cachedBarId);
    if (venue == null ||
        !await CheckinGate.ensure(context, venue) ||
        !context.mounted) {
      return;
    }
    if (_checkoutResult != null) {
      _initiatePaymentProcess(context, _checkoutResult!);
      return;
    }
    if (cartState is CheckoutSuccess) {
      // If we already have a successful checkout, just re-trigger payment process
      // (e.g. after adding a document)
      _initiatePaymentProcess(context, cartState.result);
      return;
    }

    setState(() => _isProcessing = true);

    if (cartState is CartLoaded) {
      _cachedBarId = cartState.barId;
    }

    context.read<CartBloc>().add(
      cart_event.Checkout(
        orderType: 'dine_in',
        paymentMethod: _selectedCardId == '__pix__' ? 'pix' : 'credit_card',
        tableNumber: args.locationIdentifier,
        specialInstructions: args.instructions,
        activePromotionIds: args.activePromotionIds,
      ),
    );
  }

  Future<void> _openCompleteRegistration(UserModel user) async {
    if (_isOpeningRegistration || !mounted) return;
    setState(() => _isOpeningRegistration = true);
    final completed = await context.push<bool>(
      AppRoute.completeRegistration.path,
      extra: CompleteRegistrationArguments(
        prefilledEmail: user.email,
        prefilledName: user.displayName,
        prefilledPhone: user.phoneNumber,
        termsAccepted: user.termsAccepted,
        privacyAccepted: user.privacyAccepted,
        returnToCheckout: true,
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningRegistration = false);
    if (completed == true) {
      context.read<UserBloc>().add(const UserEvent.loadCurrentUser());
    }
  }

  void _initiatePaymentProcess(BuildContext context, CheckoutResult result) {
    _checkoutResult = result;
    _cachedBarId = result.barId ?? _cachedBarId;
    if (const {
      'paid',
      'completed',
      'approved',
    }.contains(result.paymentStatus)) {
      if (mounted) setState(() => _isProcessing = false);
      context.read<CartBloc>().add(cart_event.ClearCart());
      AppRoute.goOrder(context, result.orderId);
      return;
    }

    final userState = context.read<UserBloc>().state;
    final user = userState.user;

    if (user == null) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.payment_user_session_lost,
          ),
        ),
      );
      return;
    }

    final barId = result.barId ?? _cachedBarId;
    if (barId == null) {
      setState(() => _isProcessing = false);
      return;
    }

    String? documentNumber;
    if (user.documents.isNotEmpty) {
      final doc = user.documents.firstWhere(
        (d) => d.type == DocumentType.cpf,
        orElse: () => user.documents.first,
      );
      documentNumber = doc.number;
    }

    if (documentNumber == null) {
      if (mounted) setState(() => _isProcessing = false);
      _showCpfPrompt(context, user);
      return;
    }

    if (mounted) setState(() => _isProcessing = true);

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
      orderId: result.orderId,
      barId: barId,
      amount: result.total,
      idempotencyKey: _paymentAttemptKey ??=
          result.paymentAttemptKey ?? 'order-${result.orderId}-charge',
      paymentType: paymentType,
      paymentMethodId:
          paymentType == PaymentType.credit &&
              _selectedCardId != null &&
              !_selectedCardId!.startsWith('__')
          ? int.tryParse(_selectedCardId!)
          : null,
      cardToken: null,
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

  void _listenToCartState(BuildContext context, CartState state) {
    if (state is CheckoutSuccess) {
      _initiatePaymentProcess(context, state.result);
    }
    if (state is CartError) {
      if (mounted) setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
      );
    }
  }

  void _startPixPolling(String paymentId, int orderId) {
    _pixPollTimer?.cancel();
    _pixPollCount = 0;
    _pollingPaymentId = paymentId;

    _currentPixOrderId = orderId;

    _pixPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pixPollCount++;
      if (_pixPollCount > 30) {
        // Timeout after ~90 seconds (30 polls × 3 seconds)
        timer.cancel();
        if (mounted) {
          // Dismiss modal and show timeout error
          if (_pixModalOpen) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pop(PixPaymentResult.timeout);
          }
          _currentPixPayment = null;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.payment_pix_timeout),
              backgroundColor: Colors.orange,
            ),
          );
          context.read<PaymentBloc>().add(const ClearPixPayment());
        }
        return;
      }
      if (mounted) {
        context.read<PaymentBloc>().add(CheckPaymentStatus(paymentId));
      }
    });
  }

  void _listenToPaymentState(BuildContext context, PaymentState state) {
    final transaction = state.currentTransaction;
    final expectedOrder = _checkoutResult?.orderId ?? _currentPixOrderId;
    final matches =
        expectedOrder != null &&
        (transaction?.orderId == expectedOrder ||
            (_pollingPaymentId != null &&
                transaction?.externalId == _pollingPaymentId));
    if (transaction?.isApproved == true && matches) {
      _pixPollTimer?.cancel();
      if (_pixModalOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(PixPaymentResult.approved);
      }
      _currentPixPayment = null;
      setState(() => _isProcessing = false);
      context.read<PaymentBloc>().add(const ClearPixPayment());
      context.read<CartBloc>().add(cart_event.ClearCart());
      AppRoute.goOrder(context, expectedOrder);
      return;
    }
    if (transaction?.isFailed == true && matches) {
      _paymentAttemptKey = IdempotencyKey.forPayment(expectedOrder);
      _pixPollTimer?.cancel();
      if (_pixModalOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(PixPaymentResult.cancelled);
      }
      _currentPixPayment = null;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transaction?.failureReason ??
                AppLocalizations.of(context)!.payment_failed,
          ),
        ),
      );
      return;
    }
    if (transaction != null &&
        matches &&
        !state.isProcessing &&
        _currentPixPayment == null) {
      setState(() => _isProcessing = false);
      if (transaction.externalId != null && _pixPollTimer?.isActive != true) {
        _startPixPolling(transaction.externalId!, expectedOrder);
      }
    }
    if (state.pixPayment != null &&
        _currentPixPayment == null &&
        !_pixModalOpen) {
      _currentPixPayment = state.pixPayment;
      _currentPixOrderId =
          state.pixPayment!.orderId ?? _checkoutResult?.orderId;
      _startPixPolling(state.pixPayment!.paymentId, _currentPixOrderId ?? 0);
      _pixModalOpen = true;
      PixPaymentModal.show(context, state.pixPayment!).then((result) {
        _pixModalOpen = false;
        if (!mounted) return;
        _pixPollTimer?.cancel();
        _currentPixPayment = null;
        setState(() => _isProcessing = false);
        if (context.mounted) {
          context.read<PaymentBloc>().add(const ClearPixPayment());
        }
      });
      return;
    }
    if (state.error != null) {
      if (const {400, 402, 422}.contains(state.paymentFailureStatus) &&
          expectedOrder != null) {
        _paymentAttemptKey = IdempotencyKey.forPayment(expectedOrder);
      }
      _pixPollTimer?.cancel();
      if (_pixModalOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(PixPaymentResult.cancelled);
      }
      _currentPixPayment = null;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _pixPollTimer?.cancel();
    super.dispose();
  }

  void _showCpfPrompt(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? barzDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.checkout_cpf_title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.checkout_cpf_subtitle,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.spaceGrotesk(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.checkout_cpf_label,
                  hintText: AppLocalizations.of(context)!.checkout_cpf_hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final number = controller.text.trim();
                    if (number.isNotEmpty) {
                      context.read<UserBloc>().add(
                        UserEvent.addDocument(
                          UserDocument(type: DocumentType.cpf, number: number),
                        ),
                      );
                      Navigator.pop(modalContext);
                      // After saving, we wait for the update in the listener
                      setState(() => _isWaitingForDocument = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: barzGold,
                    foregroundColor: barzDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.checkout_save_continue,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
