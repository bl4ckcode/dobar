import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart' as cart_event;
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart' as checkin_event;
import 'package:barz/features/checkin/presentation/bloc/checkin_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Enhanced cart page with table number and special instructions
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _tableController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedPaymentMethod = 'credit_card';
  String _selectedOrderType = 'dine_in';

  @override
  void dispose() {
    _tableController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getItInjector<CartBloc>()..add(cart_event.LoadCart()),
        ),
        BlocProvider(
          create: (_) => getItInjector<CheckinBloc>()..add(const checkin_event.LoadActiveCheckin()),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.cart_title),
          actions: [
            BlocBuilder<CartBloc, CartState>(
              builder: (context, state) {
                if (state is CartLoaded && state.cart.items.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showClearCartDialog(context),
                    tooltip: l10n.cart_clear,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<CartBloc, CartState>(
          listener: (context, state) {
            if (state is CheckoutSuccess) {
              _showOrderSuccessDialog(context, state.result.orderId);
            }
            if (state is CartError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is CartLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CartError) {
              return _EmptyCartView(
                message: state.message,
                isError: true,
              );
            }
            if (state is CartLoaded) {
              final cart = state.cart;
              if (cart.items.isEmpty) {
                return _EmptyCartView(message: l10n.cart_empty);
              }

              return _CartContentView(
                cart: cart,
                tableController: _tableController,
                instructionsController: _instructionsController,
                selectedPaymentMethod: _selectedPaymentMethod,
                selectedOrderType: _selectedOrderType,
                onPaymentMethodChanged: (value) {
                  setState(() => _selectedPaymentMethod = value);
                },
                onOrderTypeChanged: (value) {
                  setState(() => _selectedOrderType = value);
                },
                onCheckout: () => _handleCheckout(context),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cart_clear),
        content: const Text('Are you sure you want to clear your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CartBloc>().add(cart_event.ClearCart());
            },
            child: Text(l10n.cart_clear),
          ),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context) {
    context.read<CartBloc>().add(
          cart_event.Checkout(
            orderType: _selectedOrderType,
            paymentMethod: _selectedPaymentMethod,
            tableNumber: _tableController.text.isNotEmpty
                ? _tableController.text
                : null,
            specialInstructions: _instructionsController.text.isNotEmpty
                ? _instructionsController.text
                : null,
          ),
        );
  }

  void _showOrderSuccessDialog(BuildContext context, int orderId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 48,
            color: Colors.green,
          ),
        ),
        title: Text(l10n.checkout_success),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.checkout_order_placed),
            const SizedBox(height: 8),
            Text(
              'Order #$orderId',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/order/$orderId');
            },
            child: Text(l10n.order_tracking),
          ),
        ],
      ),
    );
  }
}

/// Empty cart view
class _EmptyCartView extends StatelessWidget {
  final String message;
  final bool isError;

  const _EmptyCartView({
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.shopping_cart_outlined,
            size: 80,
            color: isError
                ? Colors.red
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.restaurant_menu),
            label: Text(l10n.checkin_browse_menu),
          ),
        ],
      ),
    );
  }
}

/// Cart content with items, order details, and checkout
class _CartContentView extends StatelessWidget {
  final dynamic cart;
  final TextEditingController tableController;
  final TextEditingController instructionsController;
  final String selectedPaymentMethod;
  final String selectedOrderType;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<String> onOrderTypeChanged;
  final VoidCallback onCheckout;

  const _CartContentView({
    required this.cart,
    required this.tableController,
    required this.instructionsController,
    required this.selectedPaymentMethod,
    required this.selectedOrderType,
    required this.onPaymentMethodChanged,
    required this.onOrderTypeChanged,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cart Items
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_basket),
                          const SizedBox(width: 12),
                          Text(
                            l10n.cart_items(cart.totalItems),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...cart.items.map<Widget>((item) => _CartItemTile(item: item)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active check-in info
              BlocBuilder<CheckinBloc, CheckinState>(
                builder: (context, state) {
                  if (state.isCheckedIn && state.activeCheckin != null) {
                    final checkin = state.activeCheckin!;
                    // Pre-fill table number from check-in
                    if (tableController.text.isEmpty && checkin.tableNumber != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        tableController.text = checkin.tableNumber!;
                      });
                    }
                    return Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.checkin_at_bar(checkin.barName),
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (checkin.tableNumber != null)
                                    Text(
                                      'Table ${checkin.tableNumber}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),

              // Order Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.checkout_order_details,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),

                      // Order Type
                      Text(
                        l10n.checkout_order_type,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'dine_in',
                            icon: const Icon(Icons.restaurant),
                            label: Text(l10n.checkout_dine_in),
                          ),
                          ButtonSegment(
                            value: 'takeaway',
                            icon: const Icon(Icons.takeout_dining),
                            label: Text(l10n.checkout_takeaway),
                          ),
                        ],
                        selected: {selectedOrderType},
                        onSelectionChanged: (value) =>
                            onOrderTypeChanged(value.first),
                      ),
                      const SizedBox(height: 16),

                      // Table Number
                      TextField(
                        controller: tableController,
                        decoration: InputDecoration(
                          labelText: l10n.cart_table_number,
                          hintText: 'e.g., 5, A1',
                          prefixIcon: const Icon(Icons.table_bar),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Special Instructions
                      TextField(
                        controller: instructionsController,
                        decoration: InputDecoration(
                          labelText: l10n.cart_special_instructions,
                          hintText: 'Any allergies or special requests...',
                          prefixIcon: const Icon(Icons.notes),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.checkout_payment_method,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<String>(
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => onPaymentMethodChanged(value ?? selectedPaymentMethod),
                        child: Column(
                          children: [
                            _PaymentMethodRadio(
                              value: 'credit_card',
                              icon: Icons.credit_card,
                              label: l10n.payment_credit_card,
                            ),
                            _PaymentMethodRadio(
                              value: 'pix',
                              icon: Icons.qr_code,
                              label: l10n.payment_pix,
                            ),
                            _PaymentMethodRadio(
                              value: 'cash',
                              icon: Icons.money,
                              label: l10n.payment_cash,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100), // Space for bottom bar
            ],
          ),
        ),

        // Bottom checkout bar
        _CheckoutBottomBar(
          subtotal: cart.subtotal,
          itemCount: cart.totalItems,
          onCheckout: onCheckout,
        ),
      ],
    );
  }
}

/// Single cart item tile
class _CartItemTile extends StatelessWidget {
  final dynamic item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(item.menuItemName),
      subtitle: Text(
        '\$${item.unitPrice.toStringAsFixed(2)} each',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quantity controls
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 20,
            onPressed: () {
              if (item.quantity > 1) {
                context.read<CartBloc>().add(
                      cart_event.UpdateCartItem(
                        itemId: item.id,
                        quantity: item.quantity - 1,
                      ),
                    );
              } else {
                context.read<CartBloc>().add(
                      cart_event.RemoveFromCart(itemId: item.id),
                    );
              }
            },
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${item.quantity}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 20,
            onPressed: () {
              context.read<CartBloc>().add(
                    cart_event.UpdateCartItem(
                      itemId: item.id,
                      quantity: item.quantity + 1,
                    ),
                  );
            },
          ),
          const SizedBox(width: 16),
          // Item total
          SizedBox(
            width: 70,
            child: Text(
              '\$${item.totalPrice.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Payment method radio tile
class _PaymentMethodRadio extends StatelessWidget {
  final String value;
  final IconData icon;
  final String label;

  const _PaymentMethodRadio({
    required this.value,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final radioGroup = RadioGroup.maybeOf<String>(context);
    final isSelected = radioGroup?.groupValue == value;
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupRegistry: radioGroup,
      ),
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      onTap: () => radioGroup?.onChanged(value),
      contentPadding: EdgeInsets.zero,
      selected: isSelected,
    );
  }
}

/// Fixed bottom checkout bar
class _CheckoutBottomBar extends StatelessWidget {
  final double subtotal;
  final int itemCount;
  final VoidCallback onCheckout;

  const _CheckoutBottomBar({
    required this.subtotal,
    required this.itemCount,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cart_subtotal,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.payment),
              label: Text(l10n.checkout_place_order),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
