import 'package:barz/core/design/components/menu_category_pills.dart';
import 'package:barz/core/design/components/menu_header.dart';
import 'package:barz/core/design/components/menu_item_card.dart';
import 'package:barz/core/design/components/popular_item_card.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/services/color_extraction_service.dart';
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
            backgroundColor: surfacePrimary,
            body: const Center(
              child: CircularProgressIndicator(color: barzGold),
            ),
          );
        }
        if (state is BarError) {
          return Scaffold(
            backgroundColor: surfacePrimary,
            appBar: AppBar(title: Text(l10n.menu_title)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: errorRed),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      context.read<BarBloc>().add(LoadBarMenus(barId: barId));
                    },
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
              backgroundColor: surfacePrimary,
              appBar: AppBar(title: Text(l10n.menu_title)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.no_results),
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
            barImageUrl: state.barImageUrl,
            categories: categories,
            allItems: allItems,
          );
        }
        return Scaffold(
          backgroundColor: surfacePrimary,
          appBar: AppBar(title: Text(l10n.menu_title)),
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
  final String? barImageUrl;
  final Map<String, List<MenuItemModel>> categories;
  final List<MenuItemModel> allItems;

  const _MenuPageView({
    required this.barId,
    required this.barName,
    this.barImageUrl,
    required this.categories,
    required this.allItems,
  });

  @override
  State<_MenuPageView> createState() => _MenuPageViewState();
}

class _MenuPageViewState extends State<_MenuPageView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  Color _headerColor = ColorExtractionService.defaultHeaderColor;

  List<String> get _categoryList => ['All', ...widget.categories.keys.toList()];

  List<MenuItemModel> get _popularItems {
    return widget.allItems.take(6).toList();
  }

  List<MenuItemModel> get _filteredItems {
    List<MenuItemModel> items;
    if (_selectedCategoryIndex == 0) {
      items = widget.allItems;
    } else {
      final category = _categoryList[_selectedCategoryIndex];
      items = widget.categories[category] ?? [];
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item.itemName.toLowerCase().contains(_searchQuery) ||
            (item.description?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    _extractHeaderColor();
  }

  Future<void> _extractHeaderColor() async {
    if (widget.barImageUrl != null) {
      final color = await ColorExtractionService.instance.extractDominantColor(
        widget.barImageUrl,
      );
      if (mounted) {
        setState(() {
          _headerColor = color;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(MenuItemModel item) {
    final l10n = AppLocalizations.of(context)!;
    context.read<CartBloc>().add(
      AddToCart(
        menuItemId: item.id ?? 0,
        barId: widget.barId,
        menuItemName: item.itemName,
        quantity: 1,
        unitPrice: item.price,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.menu_item_added),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.cart_title,
          onPressed: () => context.push('/cart'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: surfacePrimary,
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            child: MenuHeader(
              barName: widget.barName,
              headerColor: _headerColor,
              searchController: _searchController,
              searchHint: l10n.menu_search,
              onSearchChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
              onBackTap: () => context.pop(),
              onCartTap: () => context.push('/cart'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16),
                MenuCategoryPills(
                  categories: _categoryList,
                  selectedIndex: _selectedCategoryIndex,
                  onCategorySelected: (index) {
                    setState(() => _selectedCategoryIndex = index);
                  },
                ),
                if (_popularItems.isNotEmpty && _searchQuery.isEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('⭐ Popular'),
                  const SizedBox(height: 12),
                  _buildPopularSection(),
                ],
                const SizedBox(height: 24),
                _buildSectionTitle('Full Menu'),
                const SizedBox(height: 8),
                _buildMenuList(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bar_detail_checkout_fab',
        onPressed: () => context.push('/cart'),
        backgroundColor: barzGold,
        icon: const Icon(Icons.shopping_cart, color: textOnGold),
        label: Text(
          l10n.cart_checkout,
          style: const TextStyle(
            color: textOnGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _popularItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _popularItems[index];
          return PopularItemCard(
            imageUrl: item.picture,
            name: item.itemName,
            price: item.price,
            onTap: () => _addToCart(item),
          );
        },
      ),
    );
  }

  Widget _buildMenuList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.no_results,
                style: TextStyle(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _filteredItems.map((item) {
        return MenuItemCard(
          imageUrl: item.picture,
          name: item.itemName,
          description: item.description,
          price: item.price,
          isPopular: _popularItems.contains(item),
          onAddTap: () => _addToCart(item),
          onTap: () => _showItemDetails(item),
        );
      }).toList(),
    );
  }

  void _showItemDetails(MenuItemModel item) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              item.itemName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: barzGold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 16),
              Text(
                item.description!,
                style: TextStyle(color: textSecondary, fontSize: 15),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _addToCart(item);
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(l10n.menu_item_add),
                style: FilledButton.styleFrom(
                  backgroundColor: barzGold,
                  foregroundColor: textOnGold,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
