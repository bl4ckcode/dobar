import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/spacing.dart';
import 'package:barz/core/design/tokens/radii.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';

class ExtractedItemCard extends StatelessWidget {
  final ExtractedItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const ExtractedItemCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BarzSpacing.sm),
      decoration: BoxDecoration(
        color: item.isSelected ? surfaceWhite : surfaceMuted,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(
          color: item.isSelected ? barzGold : Colors.transparent,
          width: 2,
        ),
        boxShadow: item.isSelected
            ? [
                BoxShadow(
                  color: barzGold.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(BarzRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(BarzSpacing.md),
            child: Row(
              children: [
                _buildCheckbox(),
                const SizedBox(width: BarzSpacing.md),
                Expanded(child: _buildItemInfo(context)),
                _buildPrice(context),
                const SizedBox(width: BarzSpacing.sm),
                _buildEditButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: item.isSelected ? barzGold : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: item.isSelected ? barzGold : textTertiary,
          width: 2,
        ),
      ),
      child: item.isSelected
          ? const Icon(Icons.check, size: 16, color: barzDark)
          : null,
    );
  }

  Widget _buildItemInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: item.isSelected ? textPrimary : textTertiary,
            decoration: item.isSelected ? null : TextDecoration.lineThrough,
          ),
        ),
        if (item.description != null && item.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.description!,
            style: theme.textTheme.bodySmall?.copyWith(color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPrice(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'R\$ ${item.price.toStringAsFixed(2)}',
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: item.isSelected ? barzGold : textTertiary,
      ),
    );
  }

  Widget _buildEditButton() {
    return IconButton(
      icon: const Icon(Icons.edit_outlined, size: 20),
      onPressed: onEdit,
      color: textTertiary,
      visualDensity: VisualDensity.compact,
    );
  }
}
