import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';

class WizardFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String? nextLabel;
  final bool isNextEnabled;
  final bool isLoading;
  final bool isPrimaryAction;
  final IconData? nextIcon;
  final Widget? topWidget;
  final int nextFlex;

  const WizardFooter({
    super.key,
    this.onBack,
    this.onNext,
    this.nextLabel,
    this.isNextEnabled = true,
    this.isLoading = false,
    this.isPrimaryAction = false,
    this.nextIcon,
    this.topWidget,
    this.nextFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveNextLabel = nextLabel ?? l10n.next;
    final effectiveIcon = nextIcon ?? Icons.arrow_forward;
    
    final buttonColor = isPrimaryAction ? successGreen : barzGold;
    final textColor = isPrimaryAction ? textOnDark : barzDark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topWidget != null) ...[
            topWidget!,
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: barzDark,
                      side: BorderSide(color: barzGoldMuted),
                      padding: const EdgeInsets.all(16),
                      minimumSize: const Size(0, 56),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.back,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: onBack != null ? nextFlex : 1,
                child: FilledButton(
                  onPressed: isNextEnabled && !isLoading ? onNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: textColor,
                    disabledBackgroundColor: surfaceDim,
                    disabledForegroundColor: textTertiary,
                    padding: const EdgeInsets.all(16),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPrimaryAction)
                              const Icon(Icons.check_rounded, size: 20),
                            if (isPrimaryAction) const SizedBox(width: 8),
                            Text(
                              effectiveNextLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            if (!isPrimaryAction) ...[
                              const SizedBox(width: 8),
                              Icon(effectiveIcon, size: 20),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
