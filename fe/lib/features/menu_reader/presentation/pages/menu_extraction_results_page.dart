import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_event.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_state.dart';
import 'package:barz/features/menu_reader/presentation/widgets/extracted_item_card.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MenuExtractionResultsPage extends StatelessWidget {
  final int barId;

  const MenuExtractionResultsPage({super.key, required this.barId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MenuReaderBloc, MenuReaderState>(
      listener: (context, state) {
        if (state.status == MenuReaderStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu items saved successfully!'),
              backgroundColor: successGreen,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state.status == MenuReaderStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Failed to save menu items'),
              backgroundColor: errorRed,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: barzGoldSoft,
          appBar: AppBar(
            title: const Text('Review Extracted Items'),
            backgroundColor: barzGoldSoft,
            elevation: 0,
            actions: [
              if (state.status != MenuReaderStatus.saving)
                TextButton(
                  onPressed: () => _showSelectAllDialog(context, state),
                  child: const Text('Select All'),
                ),
            ],
          ),
          body: state.status == MenuReaderStatus.saving
              ? _buildSavingState(context)
              : _buildResultsView(context, state),
          bottomNavigationBar: state.status != MenuReaderStatus.saving
              ? _buildBottomBar(context, state)
              : null,
        );
      },
    );
  }

  Widget _buildSavingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(color: barzGold, size: 60),
          const SizedBox(height: BarzSpacing.lg),
          Text(
            'Saving menu items...',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context, MenuReaderState state) {
    return Column(
      children: [
        _buildConfidenceBar(context, state),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(BarzSpacing.md),
            itemCount: state.editableCategories.length,
            itemBuilder: (context, categoryIndex) {
              final category = state.editableCategories[categoryIndex];
              return _buildCategorySection(context, category, categoryIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(BuildContext context, MenuReaderState state) {
    final confidence = state.confidence ?? 0.0;
    final confidencePercent = (confidence * 100).toInt();
    final confidenceColor = confidence >= 0.8
        ? successGreen
        : confidence >= 0.6
        ? warningOrange
        : errorRed;

    return Container(
      padding: const EdgeInsets.all(BarzSpacing.md),
      margin: const EdgeInsets.all(BarzSpacing.md),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(BarzSpacing.sm),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BarzRadii.sm),
            ),
            child: Icon(
              confidence >= 0.8 ? Icons.check_circle : Icons.info_outline,
              color: confidenceColor,
            ),
          ),
          const SizedBox(width: BarzSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Confidence: $confidencePercent%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.selectedItemCount}/${state.totalItemCount} items selected',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: textSecondary),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: surfaceDim,
                  valueColor: AlwaysStoppedAnimation(confidenceColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    ExtractedCategory category,
    int categoryIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: BarzSpacing.md,
            horizontal: BarzSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showEditCategoryDialog(
                  context,
                  category.name,
                  categoryIndex,
                ),
                color: textTertiary,
              ),
            ],
          ),
        ),
        ...category.items.asMap().entries.map((entry) {
          final itemIndex = entry.key;
          final item = entry.value;
          return ExtractedItemCard(
            item: item,
            onToggle: () {
              context.read<MenuReaderBloc>().add(
                ToggleItemSelection(
                  categoryIndex: categoryIndex,
                  itemIndex: itemIndex,
                ),
              );
            },
            onEdit: () =>
                _showEditItemDialog(context, item, categoryIndex, itemIndex),
          );
        }),
        const SizedBox(height: BarzSpacing.md),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, MenuReaderState state) {
    return Container(
      padding: EdgeInsets.only(
        left: BarzSpacing.lg,
        right: BarzSpacing.lg,
        top: BarzSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + BarzSpacing.md,
      ),
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: const BorderSide(color: textTertiary),
                padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: BarzSpacing.md),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: state.selectedItemCount > 0
                  ? () {
                      context.read<MenuReaderBloc>().add(
                        SaveExtractedItems(barId: barId),
                      );
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: Text('Save ${state.selectedItemCount} Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                disabledBackgroundColor: surfaceDim,
                padding: const EdgeInsets.symmetric(vertical: BarzSpacing.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectAllDialog(BuildContext context, MenuReaderState state) {
    final allSelected = state.selectedItemCount == state.totalItemCount;

    for (
      var catIndex = 0;
      catIndex < state.editableCategories.length;
      catIndex++
    ) {
      final category = state.editableCategories[catIndex];
      for (var itemIndex = 0; itemIndex < category.items.length; itemIndex++) {
        final item = category.items[itemIndex];
        if (allSelected ? item.isSelected : !item.isSelected) {
          context.read<MenuReaderBloc>().add(
            ToggleItemSelection(categoryIndex: catIndex, itemIndex: itemIndex),
          );
        }
      }
    }
  }

  void _showEditCategoryDialog(
    BuildContext context,
    String currentName,
    int categoryIndex,
  ) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MenuReaderBloc>().add(
                UpdateCategoryName(
                  categoryIndex: categoryIndex,
                  name: controller.text,
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(
    BuildContext context,
    ExtractedItem item,
    int categoryIndex,
    int itemIndex,
  ) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.price.toStringAsFixed(2),
    );
    final descController = TextEditingController(text: item.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BarzSpacing.md),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (R\$)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: BarzSpacing.md),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MenuReaderBloc>().add(
                UpdateItemDetails(
                  categoryIndex: categoryIndex,
                  itemIndex: itemIndex,
                  name: nameController.text,
                  price: double.tryParse(priceController.text) ?? item.price,
                  description: descController.text.isEmpty
                      ? null
                      : descController.text,
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
