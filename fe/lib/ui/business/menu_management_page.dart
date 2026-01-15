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

class _MenuManagementContentState extends State<_MenuManagementContent> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _categories = [];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _updateTabs(List<MenuModel> menus) {
    final categories = <String>{};
    for (final menu in menus) {
      for (final item in menu.items) {
        categories.add(item.category ?? 'Outros');
      }
    }
    final sortedCategories = categories.toList()..sort();
    
    if (sortedCategories.join() != _categories.join()) {
      _categories = sortedCategories;
      _tabController?.dispose();
      _tabController = TabController(length: _categories.length, vsync: this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessMenuBloc, BusinessMenuState>(
      listener: (context, state) {
        if (state.status == BusinessMenuStatus.loaded) {
          _updateTabs(state.menus);
        }
      },
      builder: (context, state) {
        if (state.status == BusinessMenuStatus.loaded && state.menus.isNotEmpty) {
          _updateTabs(state.menus);
        }
        
        return Container(
          color: barzGoldSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, state),
              if (state.status == BusinessMenuStatus.loaded && _categories.isNotEmpty)
                _buildCategoryTabs(context),
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
                '${state.totalItems} itens',
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

  Widget _buildCategoryTabs(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: barzDark,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: barzGold,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md),
        tabs: _categories.map((cat) => Tab(text: cat)).toList(),
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
        return _buildItemsGrid(context, state);
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

  Widget _buildItemsGrid(BuildContext context, BusinessMenuState state) {
    if (_tabController == null || _categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return TabBarView(
      controller: _tabController,
      children: _categories.map((category) {
        final items = <_MenuItemWithMenu>[];
        for (final menu in state.menus) {
          for (final item in menu.items) {
            if ((item.category ?? 'Outros') == category) {
              items.add(_MenuItemWithMenu(item: item, menuId: menu.id));
            }
          }
        }
        return _buildCategoryContent(context, items);
      }).toList(),
    );
  }

  Widget _buildCategoryContent(BuildContext context, List<_MenuItemWithMenu> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('Nenhum item nesta categoria', style: TextStyle(color: Colors.grey[600])),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(BarzSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 2.5,
        crossAxisSpacing: BarzSpacing.md,
        mainAxisSpacing: BarzSpacing.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _MenuItemCard(
        item: items[index].item,
        menuId: items[index].menuId,
        onEdit: () => _showEditSheet(context, items[index].menuId, items[index].item),
        onToggle: (value) => context.read<BusinessMenuBloc>().add(
          ToggleItemAvailability(
            menuId: items[index].menuId,
            itemId: items[index].item.id!,
            isAvailable: value,
          ),
        ),
        onDelete: () => _confirmDelete(context, items[index].menuId, items[index].item),
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

  void _confirmDelete(BuildContext context, int menuId, MenuItemModel item) {
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

class _MenuItemWithMenu {
  final MenuItemModel item;
  final int menuId;
  _MenuItemWithMenu({required this.item, required this.menuId});
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int menuId;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.menuId,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(BarzRadii.md),
      elevation: 0,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        child: Container(
          padding: const EdgeInsets.all(BarzSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: barzGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(BarzRadii.sm),
                ),
                child: Icon(
                  Icons.local_bar,
                  color: barzGold.withValues(alpha: 0.7),
                  size: 32,
                ),
              ),
              const SizedBox(width: BarzSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item.available ? barzDark : Colors.grey,
                        decoration: item.available ? null : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'R\$ ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: successGreen,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: item.available,
                            onChanged: item.id != null ? onToggle : null,
                            activeTrackColor: successGreen.withValues(alpha: 0.5),
                            activeThumbColor: successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
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
