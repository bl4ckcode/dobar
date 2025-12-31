import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrderDetailPage extends StatelessWidget {
  final int orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getItInjector<OrderBloc>()..add(LoadOrderTimeline(orderId: orderId)),
      child: Scaffold(
        appBar: AppBar(title: Text('Order #$orderId')),
        body: BlocBuilder<OrderBloc, OrderState>(
          builder: (context, state) {
            if (state is OrderLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is OrderError) {
              return Center(child: Text(state.message));
            }
            if (state is OrderTimelineLoaded) {
              final order = state.order;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${order.status}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Type: ${order.orderType}'),
                    Text('Payment: ${order.paymentMethod}'),
                    const SizedBox(height: 16),
                    Text('Items:',
                        style: Theme.of(context).textTheme.titleMedium),
                    ...order.items.map((item) => ListTile(
                          title: Text(item.menuItemName),
                          subtitle: Text('Qty: ${item.quantity}'),
                          trailing:
                              Text('\$${item.totalPrice.toStringAsFixed(2)}'),
                        )),
                    const Divider(),
                    Text('Subtotal: \$${order.subtotal.toStringAsFixed(2)}'),
                    Text('Tax: \$${order.tax.toStringAsFixed(2)}'),
                    Text('Tip: \$${order.tip.toStringAsFixed(2)}'),
                    Text('Total: \$${order.totalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge),
                    if (order.status == 'pending') ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<OrderBloc>()
                              .add(CancelOrder(orderId: orderId));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Cancel Order'),
                      ),
                    ],
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
