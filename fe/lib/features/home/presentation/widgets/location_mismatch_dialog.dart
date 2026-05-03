import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';

class LocationMismatchDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const LocationMismatchDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(BarzSpacing.md),
              decoration: BoxDecoration(
                color: colors.buttonPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.public,
                color: colors.buttonPrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: BarzSpacing.md),
            Text(
              l10n.location_mismatch_title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.labelPrimary,
              ),
            ),
            const SizedBox(height: BarzSpacing.sm),
            Text(
              l10n.location_mismatch_subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.labelSecondary,
              ),
            ),
            const SizedBox(height: BarzSpacing.lg),
            BarzButton.primary(
              label: l10n.location_mismatch_update_button,
              isFullWidth: true,
              onPressed: onConfirm,
            ),
            const SizedBox(height: BarzSpacing.sm),
            BarzButton.tertiary(
              label: l10n.location_mismatch_not_now_button,
              isFullWidth: true,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
