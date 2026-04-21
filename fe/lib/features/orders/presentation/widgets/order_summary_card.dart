import 'dart:ui';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/core/design/tokens/dobar_colors.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OrderSummaryCard extends StatelessWidget {
  final OrderModel order;

  const OrderSummaryCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dobarColors = context.dobarColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dobarColors.labelPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dobarColors.labelPrimary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: barzGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(LucideIcons.clipboardList, color: barzGold, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your order',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${order.items.length} items',
                            style: TextStyle(
                              color: dobarColors.labelPrimary.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'RECEIPT',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: dobarColors.labelPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Items list
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dobarColors.labelPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}×',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.menuItemName,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          // Optional: add note if available in model (not in current model)
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ).animate().fadeIn(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 100)).slideX(begin: -0.05),
              )),

              const SizedBox(height: 12),
              
              // Divider
              _DashedDivider(color: dobarColors.labelPrimary.withValues(alpha: 0.1)),
              
              const SizedBox(height: 16),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.receipt, size: 14, color: dobarColors.labelPrimary.withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Text(
                        'Paid via ${order.paymentMethod.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: dobarColors.labelPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                          color: dobarColors.labelPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        'R\$ ${order.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: barzGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
