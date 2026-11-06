import 'package:barz/features/checkin/presentation/checkin_gate.dart';
import 'package:barz/core/design/components/bar_menu_card.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/glow_button.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
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
    final colors = context.dobarColors;

    return BlocBuilder<BarBloc, BarState>(
      builder: (context, state) {
        if (state is BarLoading) {
          return const BarzLoadingWidget();
        }
        if (state is BarError) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.navBackground,
              iconTheme: IconThemeData(color: colors.labelPrimary),
              title: Text(l10n.menu_title, style: TextStyle(color: colors.labelPrimary)),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(color: colors.labelPrimary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      context.read<BarBloc>().add(LoadBarMenus(barId: barId));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.buttonPrimary,
                      side: BorderSide(color: colors.buttonPrimary),
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
              backgroundColor: colors.background,
              appBar: AppBar(
                backgroundColor: colors.navBackground,
                iconTheme: IconThemeData(color: colors.labelPrimary),
                title: Text(l10n.menu_title, style: TextStyle(color: colors.labelPrimary)),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: colors.labelSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.no_results,
                      style: TextStyle(color: colors.labelSecondary),
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
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.navBackground,
            iconTheme: IconThemeData(color: colors.labelPrimary),
            title: Text(l10n.menu_title, style: TextStyle(color: colors.labelPrimary)),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BarDetailHeader(
              barId: widget.barId,
              barName: widget.barName,
            ),
            const SizedBox(height: 16),
            _buildCategoryTabs(),
            const SizedBox(height: 8),
            Expanded(
              child: _buildMenuList(),
            ),
            _ViewTabButton(barId: widget.barId),
          ],
        ),
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
      final colors = context.dobarColors;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colors.labelSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.no_results,
              style: TextStyle(color: colors.labelSecondary),
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
        return _MenuItem(
          key: ValueKey('item_${item.id}_$_selectedCategory'),
          item: item,
          barId: widget.barId,
          index: index,
        );
      },
    );
  }
}

class _BarDetailHeader extends StatelessWidget {
  final int barId;
  final String barName;

  const _BarDetailHeader({
    required this.barId,
    required this.barName,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

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
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back,
                color: colors.labelPrimary,
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
                  barName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.buttonPrimary,
                  ),
                ),
                Text(
                  'Menu & Order',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
          _HeaderCartBadge(barId: barId),
        ],
      ),
    );
  }
}

class _HeaderCartBadge extends StatelessWidget {
  final int barId;

  const _HeaderCartBadge({required this.barId});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;

    return BlocSelector<CartBloc, CartState, int>(
      selector: (state) => state.maybeWhen(
        loaded: (cart, barId, locationConfig, activePromotions,
                selectedPromotionIds, spotAvailability, isLoading, version,
                lastSyncTimestamp) =>
            cart.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        ),
        orElse: () => 0,
      ),
      builder: (context, totalItems) {
        return GestureDetector(
          onTap: () async { if (await CheckinGate.ensure(context, barId) && context.mounted) AppRoute.cart.push(context, extra: barId); },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
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
                    color: colors.labelPrimary,
                    size: 22,
                  ),
                ),
                if (totalItems > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.buttonPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$totalItems',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.buttonOnPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final MenuItemModel item;
  final int barId;
  final int index;

  const _MenuItem({
    super.key,
    required this.item,
    required this.barId,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartBloc, CartState, int>(
      selector: (state) {
        if (state is! CartLoaded) return 0;
        final cartItem = state.cart.items
            .where((i) => i.menuItemId == item.id)
            .firstOrNull;
        return cartItem?.quantity ?? 0;
      },
      builder: (context, quantity) {
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
            onAdd: () async {
              if (!await CheckinGate.ensure(context, barId) || !context.mounted) return;
              context.read<CartBloc>().add(
                    AddToCart(
                      menuItemId: item.id ?? 0,
                      barId: barId,
                      menuItemName: item.itemName,
                      quantity: 1,
                      unitPrice: item.price,
                    ),
                  );
            },
            onRemove: () {
              context.read<CartBloc>().add(
                    DecreaseCartItem(menuItemId: item.id ?? 0),
                  );
            },
          ),
        );
      },
    );
  }
}

class _ViewTabButton extends StatelessWidget {
  final int barId;

  const _ViewTabButton({required this.barId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartBloc, CartState, ({int count, double total})>(
      selector: (state) => state.maybeWhen(
        loaded: (cart, barId, locationConfig, activePromotions,
                selectedPromotionIds, spotAvailability, isLoading, version,
                lastSyncTimestamp) =>
            (
          count: cart.items.fold<int>(0, (sum, item) => sum + item.quantity),
          total: cart.total,
        ),
        orElse: () => (count: 0, total: 0.0),
      ),
      builder: (context, data) {
        final colors = context.dobarColors;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          child: data.count > 0
              ? GlowButton(
                  label: 'View Tab',
                  badgeCount: data.count,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${data.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.buttonOnPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: colors.buttonOnPrimary, size: 20),
                    ],
                  ),
                  onPressed: () async { if (await CheckinGate.ensure(context, barId) && context.mounted) AppRoute.cart.push(context, extra: barId); },
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
