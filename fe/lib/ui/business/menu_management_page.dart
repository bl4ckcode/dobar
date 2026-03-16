import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/ui/business/bloc/business_menu_bloc.dart';
import 'package:barz/ui/business/bloc/business_menu_event.dart';
import 'package:barz/ui/business/bloc/business_menu_state.dart';

class MenuManagementPage extends StatelessWidget {
  const MenuManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, sessionState) {
        final activeBar = sessionState.currentSession?.activeBar;

        if (activeBar == null) {
          return const Center(child: Text('No active bar selected'));
        }

        return BlocProvider(
          create: (_) => BusinessMenuBloc()..add(LoadMenus(activeBar.barId)),
          child: _MenuManagementContent(barId: activeBar.barId),
        );
      },
    );
  }
}

class _MenuManagementContent extends StatefulWidget {
  final int barId;

  const _MenuManagementContent({required this.barId});

  @override
  State<_MenuManagementContent> createState() => _MenuManagementContentState();
}

class _MenuManagementContentState extends State<_MenuManagementContent> {
  final Set<int> _expandedMenus = {};
  final Set<String> _expandedCategories = {};
  bool _initializedCategories = false;

  void _toggleAllCategories(BusinessMenuState state) {
    int totalCategories = 0;
    for (final menu in state.menus) {
      final categories = <String>{};
      for (final item in menu.items) {
        categories.add(item.category ?? 'Outros');
      }
      totalCategories += categories.length;
    }

    setState(() {
      if (_expandedCategories.length >= totalCategories &&
          totalCategories > 0) {
        // Expand all was true, so collapse all
        _expandedCategories.clear();
      } else {
        // Expand all
        for (final menu in state.menus) {
          for (final item in menu.items) {
            _expandedCategories.add('${menu.id}-${item.category ?? 'Outros'}');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = dobar.background;

    return BlocConsumer<BusinessMenuBloc, BusinessMenuState>(
      listener: (context, state) {
        if (state.status == BusinessMenuStatus.loaded &&
            state.menus.isNotEmpty) {
          if (_expandedMenus.isEmpty) {
            _expandedMenus.add(state.menus.first.id);
          }
          if (!_initializedCategories) {
            for (final menu in state.menus) {
              for (final item in menu.items) {
                _expandedCategories.add(
                  '${menu.id}-${item.category ?? 'Outros'}',
                );
              }
            }
            _initializedCategories = true;
          }
        }
      },
      builder: (context, state) {
        return Container(
          color: bgColor,
          child: ResponsiveCenterContainer(
            maxWidthPercentage: 0.8,
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state, isDark),
                Expanded(child: _buildContent(context, state, isDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BusinessMenuState state,
    bool isDark,
  ) {
    final headerBg = Colors.transparent;
    final dobar = context.dobarColors;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;

    int totalCategories = 0;
    for (final menu in state.menus) {
      final categories = <String>{};
      for (final item in menu.items) {
        categories.add(item.category ?? 'Outros');
      }
      totalCategories += categories.length;
    }
    final allExpanded =
        totalCategories > 0 && _expandedCategories.length >= totalCategories;

    return Container(
      color: headerBg,
      padding: const EdgeInsets.only(
        top: BarzSpacing.xl,
        bottom: BarzSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: 'Space Grotesk',
                ),
              ),
              const SizedBox(height: BarzSpacing.xs),
              Text(
                '${state.totalItems} items across ${state.menus.length} categories',
                style: TextStyle(color: mutedTextColor, fontSize: 14),
              ),
            ],
          );

          final actionsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _toggleAllCategories(state),
                icon: AnimatedRotation(
                  turns: allExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_circle_down_outlined,
                    color: textColor,
                  ),
                ),
                tooltip: allExpanded ? 'Colapsar Tudo' : 'Expandir Tudo',
              ),
              const SizedBox(width: BarzSpacing.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<BusinessMenuBloc>().add(RefreshMenus()),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarzSpacing.md,
                    vertical: BarzSpacing.md,
                  ),
                ),
              ),
              const SizedBox(width: BarzSpacing.sm),
              FilledButton.icon(
                onPressed: () => _navigateToMenuReader(context),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(isNarrow ? 'Scan AI' : 'Scan Menu with AI'),
                style: FilledButton.styleFrom(
                  backgroundColor: barzGold,
                  foregroundColor: barzDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarzSpacing.lg,
                    vertical: BarzSpacing.md,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: BarzSpacing.md),
                actionsRow,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              actionsRow,
            ],
          );
        },
      ),
    );
  }

  Future<void> _navigateToMenuReader(BuildContext context) async {
    final saved = await context.push<bool>(
      AppRoute.businessMenuReader.path,
      extra: {'barId': widget.barId, 'menuId': 0},
    );
    if (saved == true && context.mounted) {
      context.read<BusinessMenuBloc>().add(RefreshMenus());
    }
  }

  Widget _buildContent(
    BuildContext context,
    BusinessMenuState state,
    bool isDark,
  ) {
    switch (state.status) {
      case BusinessMenuStatus.initial:
      case BusinessMenuStatus.loading:
        return const Center(child: CircularProgressIndicator(color: barzGold));

      case BusinessMenuStatus.error:
        final textColor = context.dobarColors.labelPrimary;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: BarzSpacing.md),
              Text(
                state.errorMessage ?? 'Falha ao carregar menu',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: BarzSpacing.md),
              FilledButton(
                onPressed: () => context.read<BusinessMenuBloc>().add(
                  LoadMenus(widget.barId),
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );

      case BusinessMenuStatus.loaded:
        if (state.menus.isEmpty) {
          return _buildEmptyState(context, isDark);
        }
        return _buildMenusList(context, state, isDark);
    }
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final dobar = context.dobarColors;
    final textColor = dobar.labelPrimary;
    final mutedTextColor = dobar.labelSecondary;
    final iconBg = dobar.surface;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(BarzSpacing.xl),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          Text(
            'Seu menu está vazio',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            'Escaneie um cardápio existente para começar',
            style: TextStyle(color: mutedTextColor, fontSize: 15),
          ),
          const SizedBox(height: BarzSpacing.xl),
          FilledButton.icon(
            onPressed: () => _navigateToMenuReader(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Escanear com IA'),
            style: FilledButton.styleFrom(
              backgroundColor: barzGold,
              foregroundColor: barzDark,
              padding: const EdgeInsets.symmetric(
                horizontal: BarzSpacing.xl,
                vertical: BarzSpacing.md,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenusList(
    BuildContext context,
    BusinessMenuState state,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: BarzSpacing.xl),
      itemCount: state.menus.length,
      itemBuilder: (context, index) {
        final menu = state.menus[index];
        final isExpanded = _expandedMenus.contains(menu.id);
        return _MenuSection(
          menu: menu,
          isExpanded: isExpanded,
          isDark: isDark,
          expandedCategories: _expandedCategories,
          onToggleCategory: (category) {
            setState(() {
              final key = '${menu.id}-$category';
              if (_expandedCategories.contains(key)) {
                _expandedCategories.remove(key);
              } else {
                _expandedCategories.add(key);
              }
            });
          },
          onToggle: () => setState(() {
            if (isExpanded) {
              _expandedMenus.remove(menu.id);
            } else {
              _expandedMenus.add(menu.id);
            }
          }),
          onDeleteMenu: () => _confirmDeleteMenu(context, menu),
          onEditItem: (item) => _showEditSheet(context, menu.id, item),
          onToggleItem: (item, value) => context.read<BusinessMenuBloc>().add(
            ToggleItemAvailability(
              menuId: menu.id,
              itemId: item.id!,
              isAvailable: value,
            ),
          ),
          onDeleteItem: (item) => _confirmDeleteItem(context, menu.id, item),
        );
      },
    );
  }

  void _confirmDeleteMenu(BuildContext context, MenuModel menu) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: BarzSpacing.sm),
            Text(
              'Excluir Menu',
              style: TextStyle(color: isDark ? textOnDark : textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja excluir o menu "${menu.name ?? 'Menu'}"?',
              style: TextStyle(color: isDark ? textOnDark : textPrimary),
            ),
            const SizedBox(height: BarzSpacing.sm),
            Container(
              padding: const EdgeInsets.all(BarzSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BarzRadii.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                  const SizedBox(width: BarzSpacing.xs),
                  Expanded(
                    child: Text(
                      'Isso excluirá ${menu.items.length} itens permanentemente.',
                      style: TextStyle(fontSize: 13, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BusinessMenuBloc>().add(DeleteMenu(menuId: menu.id));
            },
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Excluir Menu'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, int menuId, MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditItemSheet(
        item: item,
        onSave: (name, description, price, category) {
          context.read<BusinessMenuBloc>().add(
            UpdateMenuItem(
              menuId: menuId,
              itemId: item.id!,
              name: name,
              description: description,
              price: price,
              category: category,
            ),
          );
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _confirmDeleteItem(
    BuildContext context,
    int menuId,
    MenuItemModel item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
        title: Text(
          'Excluir Item',
          style: TextStyle(color: isDark ? textOnDark : textPrimary),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${item.itemName}"?',
          style: TextStyle(color: isDark ? textOnDark : textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (item.id != null) {
                context.read<BusinessMenuBloc>().add(
                  DeleteMenuItem(menuId: menuId, itemId: item.id!),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final MenuModel menu;
  final bool isExpanded;
  final bool isDark;
  final Set<String> expandedCategories;
  final void Function(String) onToggleCategory;
  final VoidCallback onToggle;
  final VoidCallback onDeleteMenu;
  final void Function(MenuItemModel) onEditItem;
  final void Function(MenuItemModel, bool) onToggleItem;
  final void Function(MenuItemModel) onDeleteItem;

  const _MenuSection({
    required this.menu,
    required this.isExpanded,
    required this.isDark,
    required this.expandedCategories,
    required this.onToggleCategory,
    required this.onToggle,
    required this.onDeleteMenu,
    required this.onEditItem,
    required this.onToggleItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<MenuItemModel>>{};
    for (final item in menu.items) {
      final cat = item.category ?? 'Outros';
      categories.putIfAbsent(cat, () => []).add(item);
    }
    final sortedCategories = categories.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: BarzSpacing.lg),
      child: Column(
        children: [
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.only(top: BarzSpacing.sm),
              child: Column(
                children: sortedCategories.map((category) {
                  final items = categories[category]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: BarzSpacing.md),
                    child: _CategorySection(
                      category: category,
                      items: items,
                      menuId: menu.id,
                      isDark: isDark,
                      isExpanded: expandedCategories.contains(
                        '${menu.id}-$category',
                      ),
                      onToggle: () => onToggleCategory(category),
                      onEditItem: onEditItem,
                      onToggleItem: onToggleItem,
                      onDeleteItem: onDeleteItem,
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<MenuItemModel> items;
  final int menuId;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(MenuItemModel) onEditItem;
  final void Function(MenuItemModel, bool) onToggleItem;
  final void Function(MenuItemModel) onDeleteItem;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.menuId,
    required this.isDark,
    required this.isExpanded,
    required this.onToggle,
    required this.onEditItem,
    required this.onToggleItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final headerBg = dobar.surfaceElevated;
    final textColor = dobar.labelPrimary;
    final pillBg = dobar.surfaceElevated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              children: items
                  .map(
                    (item) => _MenuItemTile(
                      item: item,
                      isDark: isDark,
                      onEdit: () => onEditItem(item),
                      onToggle: (value) => onToggleItem(item, value),
                      onDelete: () => onDeleteItem(item),
                    ),
                  )
                  .toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  final bool isDark;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _MenuItemTile({
    required this.item,
    required this.isDark,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  Widget _buildPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: barzGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
      child: Icon(
        Icons.local_bar,
        color: barzGold.withValues(alpha: 0.6),
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobar = context.dobarColors;
    final cardBg = dobar.surface;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;
    final hoverColor = isDark ? Colors.white12 : Colors.black12;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        hoverColor: hoverColor,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.picture != null && item.picture!.isNotEmpty
                    ? Image.network(
                        item.picture!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item.available ? textColor : mutedColor,
                        decoration: item.available
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.description!,
                          style: TextStyle(fontSize: 13, color: mutedColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Price
              Text(
                'R\$ ${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dobar.labelSelected,
                ),
              ),
              const SizedBox(width: 16),
              // Switch
              Switch(
                value: item.available,
                onChanged: item.id != null ? onToggle : null,
                activeTrackColor: successGreen.withValues(alpha: 0.4),
                activeThumbColor: successGreen,
              ),
              // Action Menu
              SizedBox(
                width: 32,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: mutedColor),
                  padding: EdgeInsets.zero,
                  color: dobar.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BarzRadii.sm),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: textColor),
                          const SizedBox(width: BarzSpacing.sm),
                          Text('Editar', style: TextStyle(color: textColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: errorRed),
                          const SizedBox(width: BarzSpacing.sm),
                          Text('Excluir', style: TextStyle(color: errorRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditItemSheet extends StatefulWidget {
  final MenuItemModel item;
  final void Function(
    String name,
    String? description,
    double price,
    String? category,
  )
  onSave;

  const _EditItemSheet({required this.item, required this.onSave});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _descController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(2),
    );
    _categoryController = TextEditingController(
      text: widget.item.category ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = theme.brightness == Brightness.dark;
    final bgSurface = dobar.surface;
    final textColor = dobar.labelPrimary;
    final dividerColor = isDark ? barzDarkMuted : Colors.grey[300];

    return Container(
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: BarzSpacing.lg),
              Text(
                'Editar Item',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: BarzSpacing.lg),
              _buildTextField(
                controller: _nameController,
                label: 'Nome',
                icon: Icons.restaurant,
                isDark: isDark,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: BarzSpacing.md),
              _buildTextField(
                controller: _descController,
                label: 'Descrição',
                icon: Icons.description_outlined,
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: BarzSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Preço',
                      icon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Preço obrigatório';
                        }
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Preço inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: BarzSpacing.md),
                  Expanded(
                    child: _buildTextField(
                      controller: _categoryController,
                      label: 'Categoria',
                      icon: Icons.category_outlined,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BarzSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: BarzSpacing.md,
                        ),
                        side: BorderSide(color: dividerColor!),
                        foregroundColor: textColor,
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: BarzSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: barzGold,
                        foregroundColor: barzDark,
                        padding: const EdgeInsets.symmetric(
                          vertical: BarzSpacing.md,
                        ),
                      ),
                      child: const Text('Salvar Alterações'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BarzSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final dobar = context.dobarColors;
    final fillColor = dobar.surfaceElevated;
    final borderColor = Theme.of(context).colorScheme.outline;
    final textColor = dobar.labelPrimary;
    final hintColor = dobar.labelSecondary;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: hintColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BarzRadii.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BarzRadii.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BarzRadii.sm),
          borderSide: const BorderSide(color: barzGold, width: 2),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(
        _nameController.text.trim(),
        _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        double.parse(_priceController.text.replaceAll(',', '.')),
        _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );
    }
  }
}
