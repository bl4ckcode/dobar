import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';

class PaymentOptionItem {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  PaymentOptionItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}

class PaymentOptionsGrid extends StatelessWidget {
  final List<PaymentOptionItem> options;
  final bool isDark;

  const PaymentOptionsGrid({
    super.key,
    required this.options,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final textColor = isDark ? textOnDark : textPrimary;
    final cardColor = isDark ? barzDarkLight : surfaceWhite;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'MORE OPTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: isDark ? textSecondary : textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: options.map<Widget>((option) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: option == options.last ? 0 : 12,
                  ),
                  child: GestureDetector(
                    onTap: option.onTap,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(option.icon, color: option.iconColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            option.label,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
