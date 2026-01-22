import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? barzDark : surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? barzDark : surfaceDim,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: barzDark.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? barzGold : textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? surfaceWhite : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarCategory {
  final String id;
  final String label;
  final IconData icon;

  const BarCategory({
    required this.id,
    required this.label,
    required this.icon,
  });
}

const List<BarCategory> barCategories = [
  BarCategory(id: 'bar', label: 'Bars', icon: Icons.local_bar),
  BarCategory(id: 'restaurant', label: 'Restaurants', icon: Icons.restaurant),
  BarCategory(id: 'club', label: 'Clubs', icon: Icons.nightlife),
  BarCategory(id: 'pub', label: 'Pubs', icon: Icons.sports_bar),
];
