import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class BarMenuCard extends StatefulWidget {
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const BarMenuCard({
    super.key,
    required this.name,
    this.description,
    required this.price,
    this.quantity = 0,
    this.onAdd,
    this.onRemove,
  });

  @override
  State<BarMenuCard> createState() => _BarMenuCardState();
}

class _BarMenuCardState extends State<BarMenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAdd() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onAdd?.call();
  }

  void _handleRemove() {
    widget.onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? barzDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? barzDarkMuted.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : barzDark,
                  ),
                ),
                if (widget.description != null &&
                    widget.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : barzDark.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${widget.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? barzGold : barzDark,
                ),
              ),
              const SizedBox(width: 12),
              if (widget.quantity > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.remove,
                      onTap: _handleRemove,
                      filled: false,
                      isDark: isDark,
                    ),
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '${widget.quantity}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : barzDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildActionButton(
                      icon: Icons.add,
                      onTap: _handleAdd,
                      filled: true,
                      isDark: isDark,
                    ),
                  ],
                )
              else
                _buildActionButton(
                  icon: Icons.add,
                  onTap: _handleAdd,
                  filled: false,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool filled,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? barzGold : Colors.transparent,
          border: Border.all(
            color: filled
                ? barzGold
                : (isDark ? barzDarkMuted : Colors.grey.withValues(alpha: 0.3)),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? barzDark : (isDark ? Colors.white : barzDark),
        ),
      ),
    );
  }
}
