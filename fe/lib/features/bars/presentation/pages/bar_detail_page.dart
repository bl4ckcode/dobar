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

/// Enhanced bar detail page with category tabs and better menu display
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
            appBar: AppBar(title: Text(l10n.menu_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state is BarError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.menu_title)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
              appBar: AppBar(title: Text(l10n.menu_title)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 64),
                    const SizedBox(height: 16),
                    Text(l10n.no_results),
                  ],
                ),
              ),
            );
          }

          // Build category map
          final categories = _buildCategoryMap(menus);
          
          return _MenuWithCategories(
            barId: barId,
            categories: categories,
          );
        }
        return Scaffold(
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

/// Menu page with category tabs
class _MenuWithCategories extends StatefulWidget {
  final int barId;
  final Map<String, List<MenuItemModel>> categories;

  const _MenuWithCategories({
    required this.barId,
    required this.categories,
  });

  @override
  State<_MenuWithCategories> createState() => _MenuWithCategoriesState();
}

class _MenuWithCategoriesState extends State<_MenuWithCategories>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.categories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final categoryList = widget.categories.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.menu_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => context.push('/cart'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.menu_search,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
              // Category tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: categoryList.map((category) {
                  return Tab(text: category);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categoryList.map((category) {
          final items = widget.categories[category]!;
          final filteredItems = _searchQuery.isEmpty
              ? items
              : items.where((item) {
                  return item.itemName.toLowerCase().contains(_searchQuery) ||
                      (item.description?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();

          if (filteredItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.no_results),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              return _MenuItemCard(
                item: filteredItems[index],
                barId: widget.barId,
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bar_detail_cart_fab',
        onPressed: () => context.push('/cart'),
        icon: const Icon(Icons.shopping_cart),
        label: Text(l10n.cart_checkout),
      ),
    );
  }
}

/// Individual menu item card
class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int barId;

  const _MenuItemCard({
    required this.item,
    required this.barId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Add button
              FilledButton.tonal(
                onPressed: () => _addToCart(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.read<CartBloc>().add(AddToCart(
          menuItemId: item.id ?? 0,
          barId: barId,
          menuItemName: item.itemName,
          quantity: 1,
          unitPrice: item.price,
        ));
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

  void _showItemDetails(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Item name
            Text(
              item.itemName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Price
            Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 16),
              Text(
                item.description!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            // Add to cart button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _addToCart(context);
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(l10n.menu_item_add),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
