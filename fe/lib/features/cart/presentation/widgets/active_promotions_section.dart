import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/cart_models.dart';

class ActivePromotionsSection extends StatelessWidget {
  final List<Promotion> promotions;
  final void Function(String id, bool active) onToggle;
  final Set<String> selectedIds;

  const ActivePromotionsSection({
    super.key,
    required this.promotions,
    required this.onToggle,
    this.selectedIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (promotions.isEmpty) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? barzDarkLight : surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: barzGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Active Promotions',
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...promotions.map(
            (promo) => _PromotionTile(
              promotion: promo,
              isSelected: selectedIds.contains(promo.id),
              onToggle: (active) => onToggle(promo.id, active),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  final Promotion promotion;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final bool isDark;

  const _PromotionTile({
    required this.promotion,
    required this.isSelected,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? barzGold.withValues(alpha: 0.1)
            : (isDark ? barzDarkMuted : surfaceMuted),
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? Border.all(color: barzGold.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.name,
                  style: TextStyle(
                    color: isDark ? textOnDark : textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  promotion.benefit,
                  style: TextStyle(
                    color: isSelected
                        ? barzGold
                        : (isDark ? const Color(0xFFB0B0B0) : textSecondary),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: onToggle,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return barzGold;
              }
              return isDark ? const Color(0xFF888888) : textTertiary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return barzGold.withValues(alpha: 0.3);
              }
              return isDark ? const Color(0xFF444444) : surfaceDim;
            }),
          ),
        ],
      ),
    );
  }
}
