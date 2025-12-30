import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BarDetailPage extends StatelessWidget {
  final int barId;

  const BarDetailPage({super.key, required this.barId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getItInjector<BarBloc>()..add(LoadBarMenus(barId: barId))),
        BlocProvider(create: (_) => getItInjector<CartBloc>()),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Menu')),
        body: BlocBuilder<BarBloc, BarState>(
          builder: (context, state) {
            if (state is BarLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is BarError) {
              return Center(child: Text(state.message));
            }
            if (state is MenusLoaded) {
              final menus = state.menus;
              if (menus.isEmpty) {
                return const Center(child: Text('No menu available'));
              }
              return ListView.builder(
                itemCount: menus.length,
                itemBuilder: (context, menuIndex) {
                  final menu = menus[menuIndex];
                  return _buildMenuSection(context, menu);
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          icon: const Icon(Icons.shopping_cart),
          label: const Text('View Cart'),
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, MenuModel menu) {
    final categories = <String, List<MenuItemModel>>{};
    for (final item in menu.items) {
      final category = item.category ?? 'Other';
      categories.putIfAbsent(category, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...entry.value.map((item) => ListTile(
                  title: Text(item.itemName),
                  subtitle: item.description != null
                      ? Text(item.description!)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${item.price.toStringAsFixed(2)}'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          context.read<CartBloc>().add(AddToCart(
                                menuItemId: item.id ?? 0,
                                barId: barId,
                                menuItemName: item.itemName,
                                quantity: 1,
                                unitPrice: item.price,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('${item.itemName} added to cart')),
                          );
                        },
                      ),
                    ],
                  ),
                )),
          ],
        );
      }).toList(),
    );
  }
}
