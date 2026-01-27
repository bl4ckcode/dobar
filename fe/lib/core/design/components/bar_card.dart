import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class BarCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final double rating;
  final String? imageUrl;
  final VoidCallback? onTap;

  const BarCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
    required this.rating,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: barzDarkLight,
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          border: Border.all(color: barzDarkMuted, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
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
                        barzDarkLight.withValues(alpha: 0.8),
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
                      color: barzDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 12, color: barzGold),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textOnDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 10,
                          color: textSecondary,
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
