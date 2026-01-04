import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/radii.dart';

/// Barz Button Component
/// 
/// A versatile button following Material Design 3 with Barz branding.
/// Supports multiple variants for different use cases.
/// 
/// Accessibility:
/// - Minimum touch target of 44px (WCAG 2.5.5)
/// - High contrast ratios for text
/// - Focus states for keyboard navigation

enum BarzButtonVariant {
  /// Primary action - filled with brand color
  primary,
  
  /// Secondary action - outlined
  secondary,
  
  /// Tertiary action - text only
  tertiary,
  
  /// Destructive action - red
  destructive,
}

enum BarzButtonSize {
  small,
  medium,
  large,
}

class BarzButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BarzButtonVariant variant;
  final BarzButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  
  const BarzButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BarzButtonVariant.primary,
    this.size = BarzButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });
  
  /// Primary button factory
  const BarzButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = BarzButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = BarzButtonVariant.primary;
  
  /// Secondary button factory
  const BarzButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = BarzButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = BarzButtonVariant.secondary;
  
  /// Tertiary button factory
  const BarzButton.tertiary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = BarzButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = BarzButtonVariant.tertiary;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !isLoading;
    
    final (height, horizontalPadding, fontSize, iconSize) = switch (size) {
      BarzButtonSize.small => (36.0, 16.0, 13.0, 16.0),
      BarzButtonSize.medium => (48.0, 24.0, 14.0, 20.0),
      BarzButtonSize.large => (56.0, 32.0, 16.0, 24.0),
    };
    
    final buttonStyle = _getButtonStyle(
      theme: theme,
      isEnabled: isEnabled,
      height: height,
      horizontalPadding: horizontalPadding,
    );
    
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _getContentColor(theme, isEnabled),
            ),
          ),
          const SizedBox(width: ButtonSpacing.iconGap),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize),
          const SizedBox(width: ButtonSpacing.iconGap),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: ButtonSpacing.iconGap),
          Icon(trailingIcon, size: iconSize),
        ],
      ],
    );
    
    Widget button = switch (variant) {
      BarzButtonVariant.primary => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: buttonStyle,
        child: content,
      ),
      BarzButtonVariant.secondary => OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: buttonStyle,
        child: content,
      ),
      BarzButtonVariant.tertiary => TextButton(
        onPressed: isEnabled ? onPressed : null,
        style: buttonStyle,
        child: content,
      ),
      BarzButtonVariant.destructive => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: buttonStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return errorRed.withValues(alpha: stateDisabledOpacity);
            }
            return errorRed;
          }),
        ),
        child: content,
      ),
    };
    
    if (isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }
    
    return button;
  }
  
  ButtonStyle _getButtonStyle({
    required ThemeData theme,
    required bool isEnabled,
    required double height,
    required double horizontalPadding,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(Size(0, height)),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BarzRadii.md),
        ),
      ),
      elevation: WidgetStateProperty.all(0),
      side: variant == BarzButtonVariant.secondary
          ? WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return BorderSide(
                  color: barzDark.withValues(alpha: stateDisabledOpacity),
                  width: 2,
                );
              }
              return const BorderSide(color: barzDark, width: 2);
            })
          : null,
    );
  }
  
  Color _getContentColor(ThemeData theme, bool isEnabled) {
    if (!isEnabled) {
      return theme.colorScheme.onSurface.withValues(alpha: stateDisabledOpacity);
    }
    return switch (variant) {
      BarzButtonVariant.primary => theme.colorScheme.onPrimary,
      BarzButtonVariant.secondary => theme.colorScheme.secondary,
      BarzButtonVariant.tertiary => theme.colorScheme.primary,
      BarzButtonVariant.destructive => Colors.white,
    };
  }
}
