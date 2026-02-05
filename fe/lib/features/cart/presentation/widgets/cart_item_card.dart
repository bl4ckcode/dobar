import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/cart_models.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? barzDarkLight
              : surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: barzDark.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            const SizedBox(width: 16),
            Expanded(child: _buildContent(context)),
            _buildQuantityControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 80,
        height: 80,
        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: barzGoldMuted,
      child: const Center(
        child: Icon(Icons.local_bar, color: barzGoldDark, size: 32),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          style: TextStyle(
            color: isDark ? textOnDark : textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.description,
          style: TextStyle(
            color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          '\$${item.price.toStringAsFixed(2)}',
          style: const TextStyle(
            color: barzGold,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.delete_outline,
              size: 20,
              color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuantityButton(
              icon: Icons.remove,
              onTap: () => onQuantityChanged(item.quantity - 1),
            ),
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '${item.quantity}',
                style: TextStyle(
                  color: isDark ? textOnDark : textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _QuantityButton(
              icon: Icons.add,
              onTap: () => onQuantityChanged(item.quantity + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: barzGold, width: 2),
        ),
        child: Center(child: Icon(icon, color: barzGold, size: 18)),
      ),
    );
  }
}
