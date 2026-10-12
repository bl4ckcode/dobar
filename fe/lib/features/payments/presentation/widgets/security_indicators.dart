import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';

class SecurityIndicators extends StatelessWidget {
  const SecurityIndicators({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? const Color(0xFF888888) : textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 14, color: mutedColor),
          const SizedBox(width: 6),
          Text(
            'Secure payment',
            style: TextStyle(color: mutedColor, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.shield_outlined, size: 14, color: mutedColor),
          const SizedBox(width: 6),
          Text(
            '256-bit encryption',
            style: TextStyle(color: mutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
