import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<CartBloc>()..add(LoadCart()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: BlocBuilder<CartBloc, CartState>(
          builder: (context, state) {
            if (state is CartLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CartError) {
              return Center(child: Text(state.message));
            }
            if (state is CartLoaded) {
              final cart = state.cart;
              if (cart.items.isEmpty) {
                return const Center(child: Text('Your cart is empty'));
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return ListTile(
                          title: Text(item.menuItemName),
                          subtitle: Text('Qty: ${item.quantity}'),
                          trailing: Text('\$${item.totalPrice.toStringAsFixed(2)}'),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: \$${cart.subtotal.toStringAsFixed(2)}'),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CartBloc>().add(
                                  const Checkout(
                                    orderType: 'pickup',
                                    paymentMethod: 'credit_card',
                                  ),
                                );
                          },
                          child: const Text('Checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
