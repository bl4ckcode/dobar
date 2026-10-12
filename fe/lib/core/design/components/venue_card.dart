import 'package:flutter/material.dart';
import '../design_system.dart';

class VenueCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final String crowd;
  final String? imageUrl;
  final bool isLive;
  final VoidCallback? onTap;

  const VenueCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
    required this.crowd,
    this.imageUrl,
    this.isLive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BarzRadii.md),
          border: Border.all(color: colors.surfaceElevated, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(BarzRadii.md),
                      topRight: Radius.circular(BarzRadii.md),
                    ),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colors.surfaceElevated,
                                child: Center(
                                  child: Icon(
                                    Icons.location_city,
                                    size: 48,
                                    color: colors.labelSecondary,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: colors.surfaceElevated,
                            child: Center(
                              child: Icon(
                                Icons.location_city,
                                size: 48,
                                color: colors.labelSecondary,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          colors.navBackground.withValues(alpha: 0.9),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(BarzRadii.md),
                        topRight: Radius.circular(BarzRadii.md),
                      ),
                    ),
                  ),
                ),
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(color: colors.buttonPrimary),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.buttonOnPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.buttonOnPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.labelSelected,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.navLabel,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(BarzSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colors.labelSelected,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: colors.labelSelected,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        crowd,
                        style: TextStyle(
                          fontSize: 14,
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
