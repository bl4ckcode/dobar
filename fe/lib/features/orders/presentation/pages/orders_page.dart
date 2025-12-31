import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/orders/presentation/bloc/order_bloc.dart';
import 'package:barz/features/orders/presentation/bloc/order_event.dart';
import 'package:barz/features/orders/presentation/bloc/order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<OrderBloc>()..add(const LoadMyOrders()),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: BlocBuilder<OrderBloc, OrderState>(
          builder: (context, state) {
            if (state is OrderLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is OrderError) {
              return Center(child: Text(state.message));
            }
            if (state is OrdersLoaded) {
              final orders = state.paginatedOrders.orders;
              if (orders.isEmpty) {
                return const Center(child: Text('No orders yet'));
              }
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return ListTile(
                    title: Text('Order #${order.id}'),
                    subtitle: Text(order.status),
                    trailing: Text('\$${order.totalPrice.toStringAsFixed(2)}'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/order_detail',
                        arguments: order.id,
                      );
                    },
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
