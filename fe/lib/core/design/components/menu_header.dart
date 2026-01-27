import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class MenuHeader extends StatelessWidget {
  final String barName;
  final String? tableNumber;
  final Color? headerColor;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final TextEditingController? searchController;
  final VoidCallback? onBackTap;
  final VoidCallback? onCartTap;

  const MenuHeader({
    super.key,
    required this.barName,
    this.tableNumber,
    this.headerColor,
    this.searchHint,
    this.onSearchChanged,
    this.searchController,
    this.onBackTap,
    this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = headerColor ?? const Color(0xFFFF9800);
    final hsl = HSLColor.fromColor(baseColor);
    final darkerColor = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, darkerColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopRow(context),
          const SizedBox(height: 12),
          _buildWelcomeSection(),
          const SizedBox(height: 16),
          _buildSearchBar(context),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      children: [
        if (onBackTap != null)
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        const Spacer(),
        if (tableNumber != null) _buildTableBadge(),
        if (onCartTap != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onCartTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTableBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: barzDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'Table $tableNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          barName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: const TextStyle(color: textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: searchHint ?? 'Search menu...',
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.7),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: textSecondary.withValues(alpha: 0.7),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
