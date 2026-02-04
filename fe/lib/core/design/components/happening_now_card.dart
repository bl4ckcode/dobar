import 'package:flutter/material.dart';
import '../design_system.dart';

class HappeningNowCard extends StatelessWidget {
  final String venue;
  final String event;
  final String type;
  final String? imageUrl;
  final bool isLive;
  final int attendees;
  final VoidCallback? onTap;

  const HappeningNowCard({
    super.key,
    required this.venue,
    required this.event,
    required this.type,
    this.imageUrl,
    this.isLive = false,
    required this.attendees,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 224,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          border: Border.all(color: colors.surfaceElevated, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          child: Stack(
            children: [
              if (imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: colors.surfaceElevated,
                        child: Center(
                          child: Icon(
                            Icons.music_note,
                            size: 40,
                            color: colors.labelSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: colors.surfaceElevated,
                    child: Center(
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: colors.labelSecondary,
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
                        colors.buttonPrimary.withValues(alpha: 0.2),
                        colors.buttonPrimary.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
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
                    decoration: BoxDecoration(
                      color: colors.navBackground.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.navLabel,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 12,
                            color: colors.buttonOnPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.buttonOnPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.buttonOnPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        venue,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.buttonOnPrimary.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 12,
                            color: colors.buttonOnPrimary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$attendees there',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.buttonOnPrimary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
