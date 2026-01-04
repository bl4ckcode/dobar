import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/radii.dart';

/// Barz Text Field Component
/// 
/// A versatile text input following Material Design 3 with Barz branding.
/// Features a warm, subtle gold-tinted background for brand consistency.
/// 
/// Accessibility:
/// - Clear labels and hints
/// - Error states with semantic colors
/// - Focus indicators
/// - Sufficient contrast ratios

class BarzTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool filled;
  
  const BarzTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.filled = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    
    // Auto-determine text input action
    final effectiveAction = textInputAction ?? 
        (nextFocusNode != null ? TextInputAction.next : TextInputAction.done);
    
    // Auto-determine keyboard type for multiline
    final effectiveKeyboardType = keyboardType ?? 
        ((maxLines ?? 1) > 1 ? TextInputType.multiline : TextInputType.text);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: hasError ? errorRed : textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: InputSpacing.labelGap),
        ],
        
        // Text field
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: effectiveKeyboardType,
          textInputAction: effectiveAction,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: enabled ? textPrimary : textTertiary,
          ),
          onChanged: onChanged,
          onTap: onTap,
          onEditingComplete: () {
            onEditingComplete?.call();
            if (nextFocusNode != null) {
              nextFocusNode!.requestFocus();
            }
          },
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: textTertiary,
            ),
            errorText: errorText,
            helperText: helperText,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: textSecondary,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixText: prefixText,
            suffixText: suffixText,
            filled: filled,
            fillColor: _getFillColor(hasError),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: InputSpacing.paddingHorizontal,
              vertical: InputSpacing.paddingVertical,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: barzDark, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: const BorderSide(color: errorRed, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
  
  Color _getFillColor(bool hasError) {
    if (!enabled) {
      return surfaceMuted;
    }
    if (hasError) {
      return errorRedLight;
    }
    // Subtle warm gold tint for brand consistency
    return barzGoldMuted;
  }
}

/// Barz Password Field - specialized for password input
class BarzPasswordField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  
  const BarzPasswordField({
    super.key,
    this.label,
    this.hintText = 'Enter password',
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled = true,
  });
  
  @override
  State<BarzPasswordField> createState() => _BarzPasswordFieldState();
}

class _BarzPasswordFieldState extends State<BarzPasswordField> {
  bool _obscureText = true;
  
  @override
  Widget build(BuildContext context) {
    return BarzTextField(
      label: widget.label,
      hintText: widget.hintText,
      controller: widget.controller,
      focusNode: widget.focusNode,
      nextFocusNode: widget.nextFocusNode,
      obscureText: _obscureText,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: textSecondary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}
