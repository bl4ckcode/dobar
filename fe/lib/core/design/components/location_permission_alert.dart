import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LocationPermissionAlert extends StatelessWidget {
  final String? error;
  final VoidCallback onGrant;
  final bool isLoading;

  const LocationPermissionAlert({
    super.key,
    this.error,
    required this.onGrant,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BarzSpacing.md, vertical: BarzSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.md, vertical: BarzSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(BarzRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colors.labelSelected.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: colors.labelSelected, size: 20),
          const SizedBox(width: BarzSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Required',
                  style: TextStyle(
                    color: colors.labelPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  error ?? 'Enable location to find bars near you.',
                  style: TextStyle(
                    color: colors.labelSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BarzSpacing.sm),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: onGrant,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: BarzSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Grant',
                style: TextStyle(
                  color: colors.labelSelected,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }
}
