import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barz/core/design/design_system.dart';
import '../../domain/models/search_ad.dart';
import 'featured_ad_card.dart';

/// Card widget for displaying sponsored search results.
///
/// Shows at top of search results with subtle "Patrocinado" badge.
class SearchAdCard extends StatelessWidget {
  final SearchAd ad;
  final VoidCallback? onTap;
  final VoidCallback? onVisible;

  const SearchAdCard({super.key, required this.ad, this.onTap, this.onVisible});

  @override
  Widget build(BuildContext context) {
    // Trigger onVisible when card is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onVisible?.call();
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        side: BorderSide(color: barzGold.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logo/Image
              _buildLogo(),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sponsored badge + bar name
                    Row(
                      children: [
                        const SponsoredBadge(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ad.barName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Tagline
                    Text(
                      ad.tagline,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Icon(Icons.chevron_right, color: textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: barzGoldLight,
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BarzRadii.sm),
        child: ad.logoUrl != null && ad.logoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: ad.logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _buildLogoPlaceholder(),
                errorWidget: (_, _, _) => _buildLogoPlaceholder(),
              )
            : _buildLogoPlaceholder(),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: barzGoldLight,
      child: const Icon(Icons.storefront, color: barzGoldDark, size: 28),
    );
  }
}
