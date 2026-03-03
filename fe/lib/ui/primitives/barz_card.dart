import 'package:flutter/material.dart';
import '../../core/utils/constant/colors.dart';
import '../../core/utils/constant/styles.dart';

/// Enhanced Barz Card component
///
/// Features:
/// - Subtle shadow instead of harsh border
/// - Soft border color for better appearance
/// - Optional onTap callback for interactive cards
/// - Hover effect for web
class BarzCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;

  const BarzCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = true,
  });

  @override
  State<BarzCard> createState() => _BarzCardState();
}

class _BarzCardState extends State<BarzCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: BarzSpacing.sm),
          padding: widget.padding ?? const EdgeInsets.all(BarzSpacing.md),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? barzYellow : cardBorder,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: widget.elevated
                ? [
                    BoxShadow(
                      color: _isHovered
                          ? barzYellow.withValues(alpha: 0.15)
                          : cardShadow,
                      blurRadius: _isHovered ? 12 : 8,
                      offset: Offset(0, _isHovered ? 6 : 4),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
