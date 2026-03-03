import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/shared/presentation/widget/safe_network_image.dart';

class DrinkCampaignCard extends StatelessWidget {
  final String imageUrl;
  final String barName;
  final double price;
  final VoidCallback? onTap;

  final Alignment textAlignment;

  const DrinkCampaignCard({
    super.key,
    required this.imageUrl,
    required this.barName,
    required this.price,
    this.onTap,
    this.textAlignment = Alignment.bottomLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280, // Fixed width for horizontal scrolling
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: SafeNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
              ),

              // Bottom Gradient Overlay for Text Readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Dynamic Text Overlay
              Positioned.fill(
                child: Align(
                  alignment: textAlignment,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: textAlignment == Alignment.bottomRight
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          barName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: barzGold,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
