import 'package:barz/core/design/components/bar_menu_card.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/glow_button.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_event.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BarDetailPage extends StatelessWidget {
  final int barId;

  const BarDetailPage({super.key, required this.barId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getItInjector<BarBloc>()..add(LoadBarMenus(barId: barId)),
        ),
        BlocProvider(create: (_) => getItInjector<CartBloc>()),
      ],
      child: _BarDetailContent(barId: barId),
    );
  }
}

class _BarDetailContent extends StatelessWidget {
  final int barId;

  const _BarDetailContent({required this.barId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) {
          return Scaffold(
            backgroundColor: barzDark,
            body: const Center(
              child: CircularProgressIndicator(color: barzGold),
            ),
          );
        }
        if (state is BarError) {
          return Scaffold(
            backgroundColor: barzDark,
            appBar: AppBar(
              backgroundColor: barzDark,
              foregroundColor: Colors.white,
              title: Text(l10n.menu_title),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: errorRed),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      context.read<BarBloc>().add(LoadBarMenus(barId: barId));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: barzGold,
                      side: const BorderSide(color: barzGold),
                    ),
                    child: Text(l10n.error_retry),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is MenusLoaded) {
          final menus = state.menus;
          if (menus.isEmpty) {
            return Scaffold(
              backgroundColor: barzDark,
              appBar: AppBar(
                backgroundColor: barzDark,
                foregroundColor: Colors.white,
                title: Text(l10n.menu_title),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.no_results,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = _buildCategoryMap(menus);
          final allItems = menus.expand((m) => m.items).toList();

          return _MenuPageView(
            barId: barId,
            barName: state.barName ?? 'Menu',
            categories: categories,
            allItems: allItems,
          );
        }
        return Scaffold(
          backgroundColor: barzDark,
          appBar: AppBar(
            backgroundColor: barzDark,
            foregroundColor: Colors.white,
            title: Text(l10n.menu_title),
          ),
          body: const SizedBox.shrink(),
        );
      },
    );
  }

  Map<String, List<MenuItemModel>> _buildCategoryMap(List<MenuModel> menus) {
    final categories = <String, List<MenuItemModel>>{};
    for (final menu in menus) {
      for (final item in menu.items) {
        final category = item.category ?? 'Other';
        categories.putIfAbsent(category, () => []).add(item);
      }
    }
    return categories;
  }
}

class _MenuPageView extends StatefulWidget {
  final int barId;
  final String barName;
  final Map<String, List<MenuItemModel>> categories;
  final List<MenuItemModel> allItems;

  const _MenuPageView({
    required this.barId,
    required this.barName,
    required this.categories,
    required this.allItems,
  });

  @override
  State<_MenuPageView> createState() => _MenuPageViewState();
}

class _MenuPageViewState extends State<_MenuPageView> {
  String _selectedCategory = 'All';
  final Map<int, int> _cart = {};

  List<String> get _categoryList => ['All', ...widget.categories.keys];

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.grid_view;
      case 'beer':
      case 'beers':
        return Icons.sports_bar;
      case 'cocktails':
      case 'drinks':
        return Icons.local_bar;
      case 'food':
      case 'snacks':
        return Icons.restaurant;
      case 'wine':
      case 'wines':
        return Icons.wine_bar;
      default:
        return Icons.local_cafe;
    }
  }

  List<MenuItemModel> get _filteredItems {
    if (_selectedCategory == 'All') {
      return widget.allItems;
    }
    return widget.categories[_selectedCategory] ?? [];
  }

  void _addToCart(MenuItemModel item) {
    setState(() {
      final id = item.id ?? 0;
      _cart[id] = (_cart[id] ?? 0) + 1;
    });

    context.read<CartBloc>().add(
      AddToCart(
        menuItemId: item.id ?? 0,
        barId: widget.barId,
        menuItemName: item.itemName,
        quantity: 1,
        unitPrice: item.price,
      ),
    );
  }

  void _removeFromCart(MenuItemModel item) {
    setState(() {
      final id = item.id ?? 0;
      if (_cart.containsKey(id) && _cart[id]! > 0) {
        _cart[id] = _cart[id]! - 1;
        if (_cart[id] == 0) {
          _cart.remove(id);
        }
      }
    });

    context.read<CartBloc>().add(RemoveFromCart(itemId: item.id ?? 0));
  }

  int _getItemQuantity(MenuItemModel item) {
    return _cart[item.id ?? 0] ?? 0;
  }

  int get _totalItems => _cart.values.fold(0, (sum, qty) => sum + qty);

  double get _totalPrice {
    double total = 0;
    for (final item in widget.allItems) {
      final qty = _cart[item.id ?? 0] ?? 0;
      total += item.price * qty;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildCategoryTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildMenuList()),
            _buildViewTabButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: barzDarkLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.barName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: barzGold,
                  ),
                ),
                Text(
                  'Menu & Order',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => AppRoute.cart.push(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: barzDarkLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (_totalItems > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: barzGold,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_totalItems',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: barzDark,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categoryList.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CategoryPill(
              icon: _getCategoryIcon(category),
              label: category,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedCategory = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.no_results,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final quantity = _getItemQuantity(item);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 30)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: BarMenuCard(
            name: item.itemName,
            description: item.description,
            price: item.price,
            quantity: quantity,
            onAdd: () => _addToCart(item),
            onRemove: () => _removeFromCart(item),
          ),
        );
      },
    );
  }

  Widget _buildViewTabButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      child: _totalItems > 0
          ? GlowButton(
              label: 'View Tab',
              badgeCount: _totalItems,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: barzDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: barzDark, size: 20),
                ],
              ),
              onPressed: () => AppRoute.cart.push(context),
            )
          : const SizedBox.shrink(),
    );
  }
}
