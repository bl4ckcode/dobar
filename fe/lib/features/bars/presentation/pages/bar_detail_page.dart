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
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
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
        BlocProvider.value(value: getItInjector<CartBloc>()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) {
          return Scaffold(
            backgroundColor: isDark ? barzDark : Colors.white,
            body: const Center(
              child: CircularProgressIndicator(color: barzGold),
            ),
          );
        }
        if (state is BarError) {
          return Scaffold(
            backgroundColor: isDark ? barzDark : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? barzDark : Colors.white,
              foregroundColor: isDark ? Colors.white : barzDark,
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
                    style: TextStyle(color: isDark ? Colors.white : barzDark),
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
              backgroundColor: isDark ? barzDark : Colors.white,
              appBar: AppBar(
                backgroundColor: isDark ? barzDark : Colors.white,
                foregroundColor: isDark ? Colors.white : barzDark,
                title: Text(l10n.menu_title),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : barzDark.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.no_results,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : barzDark.withValues(alpha: 0.7),
                      ),
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
          backgroundColor: isDark ? barzDark : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? barzDark : Colors.white,
            foregroundColor: isDark ? Colors.white : barzDark,
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
      case 'petiscos':
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

  int _getQuantityFromState(CartState state, int menuItemId) {
    if (state is! CartLoaded) return 0;
    final item = state.cart.items
        .where((i) => i.menuItemId == menuItemId)
        .firstOrNull;
    return item?.quantity ?? 0;
  }

  int _getTotalItemsFromState(CartState state) {
    if (state is! CartLoaded) return 0;
    return state.cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  double _getTotalPriceFromState(CartState state) {
    if (state is! CartLoaded) return 0;
    return state.cart.items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  void _addToCart(MenuItemModel item) {
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

  void _decreaseFromCart(MenuItemModel item) {
    context.read<CartBloc>().add(DecreaseCartItem(menuItemId: item.id ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        final totalItems = _getTotalItemsFromState(cartState);
        final totalPrice = _getTotalPriceFromState(cartState);

        return Scaffold(
          backgroundColor: isDark ? barzDark : Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(totalItems),
                const SizedBox(height: 16),
                _buildCategoryTabs(),
                const SizedBox(height: 8),
                Expanded(child: _buildMenuList(cartState)),
                _buildViewTabButton(totalItems, totalPrice),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(int totalItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
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
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : barzDark,
                size: 22,
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? barzGold : barzDark,
                  ),
                ),
                Text(
                  'Menu & Order',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : barzDark.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => AppRoute.cart.push(context, extra: widget.barId),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? barzDarkLight : surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: isDark ? Colors.white : barzDark,
                      size: 22,
                    ),
                  ),
                  if (totalItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: barzGold,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$totalItems',
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

  Widget _buildMenuList(CartState cartState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : barzDark.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.no_results,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : barzDark.withValues(alpha: 0.6),
              ),
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
        final quantity = _getQuantityFromState(cartState, item.id ?? 0);

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
            onRemove: () => _decreaseFromCart(item),
          ),
        );
      },
    );
  }

  Widget _buildViewTabButton(int totalItems, double totalPrice) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      child: totalItems > 0
          ? GlowButton(
              label: 'View Tab',
              badgeCount: totalItems,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${totalPrice.toStringAsFixed(2)}',
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
              onPressed: () => AppRoute.cart.push(context, extra: widget.barId),
            )
          : const SizedBox.shrink(),
    );
  }
}
