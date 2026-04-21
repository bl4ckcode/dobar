import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VenueTableInfo extends StatelessWidget {
  final String tableNumber;
  final VoidCallback onCallWaiter;
  final VoidCallback onDirections;

  const VenueTableInfo({
    super.key,
    required this.tableNumber,
    required this.onCallWaiter,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final dobarColors = context.dobarColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Table box
            _InfoBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 24) / 3,
              colors: dobarColors,
              label: 'TABLE',
              value: tableNumber,
              iconPath: LucideIcons.layoutGrid,
              isGradient: true,
            ),

            // Call Waiter Button
            _ActionButton(
              width: isNarrow
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 24) / 3,
              colors: dobarColors,
              label: 'Call waiter',
              icon: LucideIcons.bellRing,
              onPressed: onCallWaiter,
            ),

            // Directions Button
            _ActionButton(
              width: isNarrow
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 24) / 3,
              colors: dobarColors,
              label: 'Directions',
              icon: LucideIcons.mapPin,
              onPressed: onDirections,
            ),
          ],
        );
      },
    );
  }
}

class _InfoBox extends StatelessWidget {
  final double width;
  final DobarColors colors;
  final String label;
  final String value;
  final IconData iconPath;
  final bool isGradient;

  const _InfoBox({
    required this.width,
    required this.colors,
    required this.label,
    required this.value,
    required this.iconPath,
    this.isGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.labelPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isGradient
                  ? LinearGradient(
                      colors: [barzGold, barzGold.withValues(alpha: 0.8)],
                    )
                  : null,
              color: !isGradient ? barzGold.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isGradient
                  ? [
                      BoxShadow(
                        color: barzGold.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              iconPath,
              color: isGradient ? barzDark : barzGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: colors.labelPrimary.withValues(alpha: 0.4),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final double width;
  final DobarColors colors;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.width,
    required this.colors,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.labelPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: barzGold, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
