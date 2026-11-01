import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../design_system.dart';

enum BarBadge { promo, happyHour, cashback }

class BarCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final double rating;
  final String? imageUrl;
  final VoidCallback? onTap;
  final List<BarBadge> badges;

  const BarCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
    required this.rating,
    this.imageUrl,
    this.onTap,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          border: Border.all(color: colors.surfaceElevated, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(BarzRadii.lg),
                      topRight: Radius.circular(BarzRadii.lg),
                    ),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.brightness == Brightness.light
                            ? const Color(0xFFFFFDE7).withValues(alpha: 0.8)
                            : colors.surface.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(BarzRadii.lg),
                      topRight: Radius.circular(BarzRadii.lg),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.navBackground.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: colors.labelSelected),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.navLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (badges.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 40,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: badges
                          .map((b) => _BadgePill(badge: b))
                          .toList(),
                    ),
                  ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? const Color(0xFFFFFDF5)
                    : null,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(BarzRadii.lg),
                  bottomRight: Radius.circular(BarzRadii.lg),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.labelPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.labelSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: colors.labelSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final BarBadge badge;
  const _BadgePill({required this.badge});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (String label, IconData icon, Color bg, Color fg) = switch (badge) {
      BarBadge.promo => (
        l10n.home_badge_promotion,
        LucideIcons.tag,
        barzGold,
        barzDark,
      ),
      BarBadge.happyHour => (
        l10n.home_badge_happy_hour,
        LucideIcons.clock_3,
        const Color(0xFFFF8A3D),
        barzDark,
      ),
      BarBadge.cashback => (
        l10n.home_badge_cashback,
        LucideIcons.coins,
        const Color(0xFF22B985),
        barzDark,
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
