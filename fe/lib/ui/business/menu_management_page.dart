import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/components/responsive_center_container.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessMenuBloc, BusinessMenuState>(
      listener: (context, state) {
        if (state.status == BusinessMenuStatus.loaded && state.menus.isNotEmpty) {
          if (_expandedMenus.isEmpty) {
            _expandedMenus.add(state.menus.first.id);
          }
        }
      },
      builder: (context, state) {
        return Container(
          color: barzGoldSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, state),
              Expanded(
                child: ResponsiveCenterContainer(
                  maxWidthPercentage: 0.8,
                  maxWidth: 1200,
                  padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
                  child: _buildContent(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BusinessMenuState state) {
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: barzDark,
                ),
              ),
              const SizedBox(height: BarzSpacing.xs),
              Text(
                '${state.menus.length} ${state.menus.length == 1 ? 'menu' : 'menus'} • ${state.totalItems} itens',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => context.read<BusinessMenuBloc>().add(RefreshMenus()),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: barzDark,
                ),
              ),
              const SizedBox(width: BarzSpacing.sm),
              FilledButton.icon(
                onPressed: () => _navigateToMenuReader(context),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Escanear Menu'),
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
          ),
        ],
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

  Widget _buildContent(BuildContext context, BusinessMenuState state) {
    switch (state.status) {
      case BusinessMenuStatus.initial:
      case BusinessMenuStatus.loading:
        return const Center(child: CircularProgressIndicator(color: barzGold));
      
      case BusinessMenuStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: BarzSpacing.md),
              Text(state.errorMessage ?? 'Falha ao carregar menu'),
              const SizedBox(height: BarzSpacing.md),
              FilledButton(
                onPressed: () => context.read<BusinessMenuBloc>().add(LoadMenus(widget.barId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
      
      case BusinessMenuStatus.loaded:
        if (state.menus.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildMenusList(context, state);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(BarzSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: BarzSpacing.xl),
          const Text(
            'Seu menu está vazio',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: barzDark),
          ),
          const SizedBox(height: BarzSpacing.sm),
          Text(
            'Escaneie um cardápio existente para começar',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
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

  Widget _buildMenusList(BuildContext context, BusinessMenuState state) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: BarzSpacing.xl),
      itemCount: state.menus.length,
      itemBuilder: (context, index) {
        final menu = state.menus[index];
        final isExpanded = _expandedMenus.contains(menu.id);
        return _MenuSection(
          menu: menu,
          isExpanded: isExpanded,
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: BarzSpacing.sm),
            const Text('Excluir Menu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja excluir o menu "${menu.name ?? 'Menu'}"?'),
            const SizedBox(height: BarzSpacing.sm),
            Container(
              padding: const EdgeInsets.all(BarzSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.red[50],
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

  void _confirmDeleteItem(BuildContext context, int menuId, MenuItemModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.md)),
        title: const Text('Excluir Item'),
        content: Text('Tem certeza que deseja excluir "${item.itemName}"?'),
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
  final VoidCallback onToggle;
  final VoidCallback onDeleteMenu;
  final void Function(MenuItemModel) onEditItem;
  final void Function(MenuItemModel, bool) onToggleItem;
  final void Function(MenuItemModel) onDeleteItem;

  const _MenuSection({
    required this.menu,
    required this.isExpanded,
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
      margin: const EdgeInsets.only(bottom: BarzSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(BarzRadii.md),
              bottom: isExpanded ? Radius.zero : const Radius.circular(BarzRadii.md),
            ),
            child: Container(
              padding: const EdgeInsets.all(BarzSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(BarzSpacing.sm),
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(BarzRadii.sm),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: barzGold, size: 24),
                  ),
                  const SizedBox(width: BarzSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name ?? 'Menu',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: barzDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${menu.items.length} itens • ${sortedCategories.length} ${sortedCategories.length == 1 ? 'categoria' : 'categorias'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.sm)),
                    onSelected: (value) {
                      if (value == 'delete') onDeleteMenu();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                            const SizedBox(width: BarzSpacing.sm),
                            Text('Excluir Menu', style: TextStyle(color: Colors.red[400])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: sortedCategories.map((category) {
                  final items = categories[category]!;
                  return _CategorySection(
                    category: category,
                    items: items,
                    menuId: menu.id,
                    onEditItem: onEditItem,
                    onToggleItem: onToggleItem,
                    onDeleteItem: onDeleteItem,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
  final void Function(MenuItemModel) onEditItem;
  final void Function(MenuItemModel, bool) onToggleItem;
  final void Function(MenuItemModel) onDeleteItem;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.menuId,
    required this.onEditItem,
    required this.onToggleItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BarzSpacing.md,
            vertical: BarzSpacing.sm,
          ),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: BarzSpacing.xs),
              Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: BarzSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: barzDark),
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _MenuItemTile(
          item: item,
          onEdit: () => onEditItem(item),
          onToggle: (value) => onToggleItem(item, value),
          onDelete: () => onDeleteItem(item),
        )),
      ],
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _MenuItemTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BarzSpacing.md,
          vertical: BarzSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: barzGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BarzRadii.sm),
              ),
              child: Icon(
                Icons.local_bar,
                color: barzGold.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(width: BarzSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: item.available ? barzDark : Colors.grey,
                      decoration: item.available ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  if (item.description != null && item.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: BarzSpacing.sm),
            Text(
              'R\$ ${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: successGreen,
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: item.available,
                onChanged: item.id != null ? onToggle : null,
                activeTrackColor: successGreen.withValues(alpha: 0.4),
                activeThumbColor: successGreen,
              ),
            ),
            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BarzRadii.sm)),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: BarzSpacing.sm),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                        const SizedBox(width: BarzSpacing.sm),
                        Text('Excluir', style: TextStyle(color: Colors.red[400])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditItemSheet extends StatefulWidget {
  final MenuItemModel item;
  final void Function(String name, String? description, double price, String? category) onSave;

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
    _descController = TextEditingController(text: widget.item.description ?? '');
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _categoryController = TextEditingController(text: widget.item.category ?? '');
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: BarzSpacing.lg),
              const Text(
                'Editar Item',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: barzDark),
              ),
              const SizedBox(height: BarzSpacing.lg),
              _buildTextField(
                controller: _nameController,
                label: 'Nome',
                icon: Icons.restaurant,
                validator: (v) => v == null || v.isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: BarzSpacing.md),
              _buildTextField(
                controller: _descController,
                label: 'Descrição',
                icon: Icons.description_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: BarzSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Preço',
                      icon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Preço obrigatório';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Preço inválido';
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
                        padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
                        side: BorderSide(color: Colors.grey[300]!),
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
                        padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
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
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BarzRadii.sm),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BarzRadii.sm),
          borderSide: BorderSide(color: Colors.grey[200]!),
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
        _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        double.parse(_priceController.text.replaceAll(',', '.')),
        _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      );
    }
  }
}
