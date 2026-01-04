import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/radii.dart';

/// Barz Card Component
/// 
/// A versatile container for grouping related content.
/// Uses subtle shadows and warm colors for a friendly feel.

class BarzCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final double? elevation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const BarzCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.elevation,
    this.onTap,
    this.onLongPress,
  });
  
  /// Elevated card with shadow
  const BarzCard.elevated({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CardSpacing.padding),
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.onLongPress,
  })  : borderColor = null,
        borderWidth = null,
        borderRadius = BarzRadii.md,
        elevation = 2.0;
  
  /// Outlined card with border
  const BarzCard.outlined({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CardSpacing.padding),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.onLongPress,
  })  : borderWidth = 1.0,
        borderRadius = BarzRadii.md,
        elevation = 0.0;
  
  /// Filled card with background color
  const BarzCard.filled({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CardSpacing.padding),
    this.margin,
    this.backgroundColor = barzGoldMuted,
    this.onTap,
    this.onLongPress,
  })  : borderColor = null,
        borderWidth = null,
        borderRadius = BarzRadii.md,
        elevation = 0.0;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderRadius = borderRadius ?? BarzRadii.md;
    final effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.surface;
    final effectiveBorderColor = borderColor ?? theme.colorScheme.outline;
    
    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        border: borderWidth != null && borderWidth! > 0
            ? Border.all(color: effectiveBorderColor, width: borderWidth!)
            : null,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: barzDark.withValues(alpha: 0.08),
                  blurRadius: elevation! * 2,
                  offset: Offset(0, elevation!),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
    
    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          child: card,
        ),
      );
    }
    
    return card;
  }
}

/// Barz List Tile Card - for list items with icon and chevron
class BarzListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isDestructive;
  
  const BarzListTile({
    super.key,
    this.leadingIcon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDestructive ? errorRed : textPrimary;
    final iconColor = isDestructive ? errorRed : barzGold;
    
    return BarzCard.elevated(
      onTap: onTap,
      padding: const EdgeInsets.all(CardSpacing.padding),
      child: Row(
        children: [
          // Leading
          if (leading != null)
            leading!
          else if (leadingIcon != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(BarzRadii.sm),
              ),
              child: Icon(
                leadingIcon,
                color: iconColor,
                size: 22,
              ),
            ),
          
          if (leadingIcon != null || leading != null)
            const SizedBox(width: BarzSpacing.md),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: BarzSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Trailing
          if (trailing != null)
            trailing!
          else if (showChevron && onTap != null)
            Icon(
              Icons.chevron_right,
              color: textTertiary,
              size: 24,
            ),
        ],
      ),
    );
  }
}
