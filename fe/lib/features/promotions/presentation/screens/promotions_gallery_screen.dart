import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import 'package:barz/features/promotions/presentation/widgets/drink_campaign_card.dart';
import 'package:barz/features/promotions/presentation/widgets/promo_card.dart';
import 'package:barz/features/promotions/presentation/widgets/vip_upgrade_banner.dart';

class PromotionsGalleryScreen extends StatelessWidget {
  const PromotionsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Promotions Gallery'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Promotional Callouts', 'Happy Hour & Events'),
            const SizedBox(height: 16),

            // Happy Hour - Active
            const Text(
              'Active State',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            PromoCard(
              // Using local asset for testing
              imageUrl: 'marketing_mockups/happy_hour_template.png',
              timeRange: '18:00 - 20:00',
              isActive: true,
            ),

            const SizedBox(height: 16),

            // Happy Hour - Future
            const Text(
              'Future State',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const PromoCard(
              imageUrl: 'marketing_mockups/happy_hour_template.png',
              timeRange: '20:00 - 22:00',
              isActive: false,
            ),

            const SizedBox(height: 32),
            _buildSectionHeader(
              'Drink Campaigns',
              'Hottest Drinks (Horizontal Scroll)',
            ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  DrinkCampaignCard(
                    imageUrl: 'marketing_mockups/caipirinha_concept.png',
                    barName: 'Baxo Bar',
                    price: 32.00,
                  ),
                  const SizedBox(width: 16),
                  DrinkCampaignCard(
                    imageUrl: 'marketing_mockups/pina_colada_template.png',
                    barName: 'Tatu Bola',
                    price: 28.50,
                    textAlignment: Alignment.bottomRight,
                  ),
                  const SizedBox(width: 16),
                  DrinkCampaignCard(
                    imageUrl: 'marketing_mockups/moscow_mule_template.png',
                    barName: 'Vila Seu Justino',
                    price: 35.00,
                    textAlignment: Alignment.bottomRight,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('VIP Engagement', 'Upgrade Banners'),
            const SizedBox(height: 16),

            const VIPUpgradeBanner(
              imageUrl: 'marketing_mockups/vip_cashback.png',
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: barzDark,
          ),
        ),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }
}
