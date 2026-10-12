import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barz/core/design/design_system.dart';
import '../../domain/models/featured_ad.dart';

/// Card widget for displaying featured ads in home carousel.
///
/// Features:
/// - Gradient overlay for text readability
/// - Distance badge
/// - Tap to navigate to bar
/// - Visibility callback for impression tracking
class FeaturedAdCard extends StatelessWidget {
  final FeaturedAd ad;
  final VoidCallback? onTap;
  final VoidCallback? onVisible;

  const FeaturedAdCard({
    super.key,
    required this.ad,
    this.onTap,
    this.onVisible,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger onVisible when card is built (simple visibility tracking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onVisible?.call();
    });

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BarzRadii.lg),
          child: Stack(
            children: [
              // Background image or gradient
              _buildBackground(),
              // Gradient overlay for text readability
              _buildGradientOverlay(),
              // Content
              _buildContent(),
              // Sponsored badge
              const Positioned(top: 12, left: 12, child: SponsoredBadge()),
              // Distance badge
              Positioned(top: 12, right: 12, child: _buildDistanceBadge()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (ad.logoUrl != null && ad.logoUrl!.isNotEmpty) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: ad.logoUrl!,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: barzGoldLight),
          errorWidget: (_, _, _) => _buildFallbackBackground(),
        ),
      );
    }
    return _buildFallbackBackground();
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [barzDark, barzDarkLight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 64,
          color: barzGold.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.3, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ad.barName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            ad.tagline,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${ad.distanceKm.toStringAsFixed(1)} km',
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
}

/// Small badge indicating sponsored content.
/// Use on any sponsored item (cards, list items, etc.)
class SponsoredBadge extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;

  const SponsoredBadge({
    super.key,
    this.backgroundColor = barzGold,
    this.textColor = barzDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            'Patrocinado',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
