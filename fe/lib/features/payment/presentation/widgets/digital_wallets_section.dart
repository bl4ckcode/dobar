import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';

class DigitalWalletsSection extends StatelessWidget {
  final VoidCallback onApplePay;
  final VoidCallback onGooglePay;

  const DigitalWalletsSection({
    super.key,
    required this.onApplePay,
    required this.onGooglePay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFDDDDDD),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or pay with',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF888888) : textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFDDDDDD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildApplePayButton(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildGooglePayButton(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplePayButton(bool isDark) {
    return GestureDetector(
      onTap: onApplePay,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : barzDark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: barzDark.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/apple.png',
              width: 20,
              height: 20,
              color: isDark ? barzDark : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'Pay',
              style: TextStyle(
                color: isDark ? barzDark : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGooglePayButton(bool isDark) {
    return GestureDetector(
      onTap: onGooglePay,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
          ),
          boxShadow: [
            BoxShadow(
              color: barzDark.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/google.png',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Pay',
              style: TextStyle(
                color: isDark ? Colors.white : barzDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
