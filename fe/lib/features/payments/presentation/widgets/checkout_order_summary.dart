import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/checkout_models.dart';

class CheckoutOrderSummary extends StatefulWidget {
  final List<OrderItem> items;
  final double subtotal;
  final OrderDiscount? discount;
  final double cashback;
  final double total;
  final bool isPro;

  const CheckoutOrderSummary({
    super.key,
    required this.items,
    required this.subtotal,
    this.discount,
    required this.cashback,
    required this.total,
    this.isPro = false,
  });

  @override
  State<CheckoutOrderSummary> createState() => _CheckoutOrderSummaryState();
}

class _CheckoutOrderSummaryState extends State<CheckoutOrderSummary>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? barzDarkLight : surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: barzDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_offer_outlined,
                      color: barzGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order Summary',
                              style: TextStyle(
                                color: isDark ? textOnDark : textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (widget.isPro) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: barzGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Priority ⚡️',
                                  style: TextStyle(
                                    color: barzGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${widget.items.length} ${widget.items.length == 1 ? "item" : "items"}',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFB0B0B0)
                                : textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency(widget.total),
                    style: const TextStyle(
                      color: barzGold,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(
            height: 1,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 16),
          ...widget.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.quantity}x ${item.name}',
                    style: TextStyle(
                      color: isDark ? textOnDark : textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatCurrency(item.total),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Subtotal',
            _formatCurrency(widget.subtotal),
            isDark,
          ),
          if (widget.discount != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      color: successGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Discount (${widget.discount!.code})',
                      style: const TextStyle(color: successGreen, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '-${_formatCurrency(widget.discount!.amount)}',
                  style: const TextStyle(color: successGreen, fontSize: 14),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.paid_outlined, color: barzGold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    widget.isPro ? 'Cashback (PRO 10%)' : 'Cashback you\'ll earn',
                    style: const TextStyle(color: barzGold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '+${_formatCurrency(widget.cashback)}',
                style: const TextStyle(color: barzGold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                _formatCurrency(widget.total),
                style: TextStyle(
                  color: isDark
                      ? barzGold
                      : Colors.black, // Explicit black for light mode
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? textOnDark : textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
