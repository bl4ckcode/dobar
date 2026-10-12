import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/shared/presentation/widget/safe_network_image.dart';

class VIPUpgradeBanner extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const VIPUpgradeBanner({super.key, required this.imageUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Gradient border effect
          gradient: LinearGradient(
            colors: [barzGold, barzDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: barzGold.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0), // Border width
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Background Image
                Positioned.fill(
                  child: SafeNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),

                // Content is baked into the image for this one, as per design specs
                // But we add a subtle shimmer overlay or material ripple
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      splashColor: barzGold.withValues(alpha: 0.2),
                      highlightColor: barzGold.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
