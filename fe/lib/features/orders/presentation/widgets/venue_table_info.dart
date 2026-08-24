import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        final double itemSpacing = constraints.maxWidth < 360 ? 4 : 8;
        
        return Row(
          children: [
            Expanded(
              flex: 10,
              child: _InfoBox(
                colors: dobarColors,
                label: 'TABLE',
                value: tableNumber,
                iconPath: LucideIcons.layoutGrid,
                isGradient: true,
              ),
            ),
            SizedBox(width: itemSpacing),
            Expanded(
              flex: 11,
              child: _ActionButton(
                colors: dobarColors,
                label: 'Call waiter',
                icon: LucideIcons.bellRing,
                onPressed: onCallWaiter,
              ),
            ),
            SizedBox(width: itemSpacing),
            Expanded(
              flex: 11,
              child: _ActionButton(
                colors: dobarColors,
                label: 'Directions',
                icon: LucideIcons.mapPin,
                onPressed: onDirections,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoBox extends StatelessWidget {
  final DobarColors colors;
  final String label;
  final String value;
  final IconData iconPath;
  final bool isGradient;

  const _InfoBox({
    required this.colors,
    required this.label,
    required this.value,
    required this.iconPath,
    this.isGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: colors.labelPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isGradient
                  ? const LinearGradient(
                      colors: [barzGoldGradientStart, barzGoldGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: !isGradient ? barzGold.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isGradient
                  ? [
                      BoxShadow(
                        color: barzGold.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              iconPath,
              color: isGradient ? barzDark : barzGold,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: colors.labelPrimary.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              height: 1,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final DobarColors colors;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.colors,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.labelPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.labelPrimary.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: barzGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: barzGold, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4), // Balance height with _InfoBox
          ],
        ),
      ),
    );
  }
}
