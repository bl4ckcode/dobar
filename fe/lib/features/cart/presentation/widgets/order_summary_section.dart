import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/cart_models.dart';

class OrderSummarySection extends StatefulWidget {
  final List<CartItem> items;
  final Coupon? coupon;
  final List<Promotion> promotions;
  final VoidCallback onCheckout;
  final double? overrideTotal;
  final double? overrideDiscount;
  final bool isLoading;
  final bool isExpanded;
  final VoidCallback onToggle;

  const OrderSummarySection({
    super.key,
    required this.items,
    required this.coupon,
    required this.promotions,
    required this.onCheckout,
    required this.isExpanded,
    required this.onToggle,
    this.overrideTotal,
    this.overrideDiscount,
    this.isLoading = false,
  });

  @override
  State<OrderSummarySection> createState() => _OrderSummarySectionState();
}

class _OrderSummarySectionState extends State<OrderSummarySection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subtotal = widget.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    final couponDiscount =
        widget.overrideDiscount ??
        (widget.coupon?.calculateDiscount(subtotal) ?? 0);

    final activePromos = widget.promotions.where((p) => p.active).toList();
    final cashbackPercentage = activePromos.fold<double>(
      0,
      (sum, p) => sum + (p.cashbackPercentage ?? 0),
    );
    final cashbackAmount = subtotal * (cashbackPercentage / 100);

    final total = widget.overrideTotal ?? (subtotal - couponDiscount);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        left: 16,
        right: 16,
        bottom: 24 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? barzDarkLight : surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle / Toggle
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? barzDarkMuted : surfaceDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  widget.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: isDark ? textSecondary : textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),

          // Expandable Details
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? Column(
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: '\$${subtotal.toStringAsFixed(2)}',
                        isDark: isDark,
                      ),
                      if (couponDiscount > 0) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Coupon (${widget.coupon!.code})',
                          value: '-\$${couponDiscount.toStringAsFixed(2)}',
                          isDark: isDark,
                          isHighlight: true,
                        ),
                      ],
                      if (cashbackAmount > 0) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Cashback (${cashbackPercentage.toInt()}%)',
                          value: '+\$${cashbackAmount.toStringAsFixed(2)}',
                          isDark: isDark,
                          isHighlight: true,
                          isCashback: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: isDark ? barzDarkMuted : surfaceDim,
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Total & Checkout (Always visible)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: barzGold,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (cashbackAmount > 0)
                    Text(
                      '+ \$${cashbackAmount.toStringAsFixed(2)} cashback',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CheckoutButton(
            onPressed: widget.items.isEmpty ? null : widget.onCheckout,
            isLoading: widget.isLoading,
          ),
          if (widget.isExpanded) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: isDark ? const Color(0xFF888888) : textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Secure checkout powered by encrypted payment',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF888888) : textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isHighlight;
  final bool isCashback;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.isHighlight = false,
    this.isCashback = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight
                ? (isCashback ? barzGold.withValues(alpha: 0.8) : barzGold)
                : (isDark ? const Color(0xFFB0B0B0) : textSecondary),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? barzGold : (isDark ? textOnDark : textPrimary),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _CheckoutButton({required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isEnabled ? barzGold : barzGold.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: barzGold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isEnabled ? barzDark : barzDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            Text(
              isLoading ? 'Updating...' : 'Proceed to Payment',
              style: TextStyle(
                color: isEnabled ? barzDark : barzDark.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isLoading) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                color: isEnabled ? barzDark : barzDark.withValues(alpha: 0.6),
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
