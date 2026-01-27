import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../tokens/colors.dart';

class MenuItemCard extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? description;
  final double price;
  final bool isPopular;
  final VoidCallback? onAddTap;
  final VoidCallback? onTap;

  const MenuItemCard({
    super.key,
    this.imageUrl,
    required this.name,
    this.description,
    required this.price,
    this.isPopular = false,
    this.onAddTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: barzDark.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            const SizedBox(width: 12),
            Expanded(child: _buildContent()),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 80,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildPlaceholder(),
                errorWidget: (_, __, ___) => _buildPlaceholder(),
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isPopular) ...[const SizedBox(width: 8), _buildPopularBadge()],
          ],
        ),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(color: textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: const TextStyle(
            color: barzGold,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPopularBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800), width: 1),
      ),
      child: const Text(
        'Popular',
        style: TextStyle(
          color: Color(0xFFE65100),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: barzGold, width: 2),
        ),
        child: const Center(child: Icon(Icons.add, color: barzGold, size: 20)),
      ),
    );
  }
}
