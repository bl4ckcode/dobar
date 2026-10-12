import 'package:flutter/material.dart';
import '../../core/design/design_system.dart';

class ShowcaseScreen extends StatelessWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzDark,
      appBar: AppBar(
        backgroundColor: barzDark,
        elevation: 0,
        title: const Text(
          'Design System Showcase',
          style: TextStyle(fontWeight: FontWeight.bold, color: textOnDark),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textOnDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          _buildSection(
            title: 'Colors',
            child: Wrap(
              spacing: BarzSpacing.sm,
              runSpacing: BarzSpacing.sm,
              children: [
                _colorSwatch('Primary', barzGold),
                _colorSwatch('Background', barzDark),
                _colorSwatch('Surface', barzDarkLight),
                _colorSwatch('Border', barzDarkMuted),
              ],
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Buttons',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarzButton.primary(label: 'Primary Button', onPressed: () {}),
                const SizedBox(height: BarzSpacing.sm),
                BarzButton.secondary(
                  label: 'Secondary Button',
                  onPressed: () {},
                ),
                const SizedBox(height: BarzSpacing.sm),
                BarzButton.tertiary(label: 'Tertiary Button', onPressed: () {}),
                const SizedBox(height: BarzSpacing.sm),
                BarzButton.primary(
                  label: 'With Icon',
                  leadingIcon: Icons.add,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Cards',
            child: Column(
              children: [
                BarzCard.sharp(
                  child: const Padding(
                    padding: EdgeInsets.all(BarzSpacing.md),
                    child: Text(
                      'Sharp Card (Industrial Default)',
                      style: TextStyle(color: textOnDark),
                    ),
                  ),
                ),
                const SizedBox(height: BarzSpacing.sm),
                BarzCard.glass(
                  child: const Padding(
                    padding: EdgeInsets.all(BarzSpacing.md),
                    child: Text(
                      'Glass Card (Glassmorphism)',
                      style: TextStyle(color: textOnDark),
                    ),
                  ),
                ),
                const SizedBox(height: BarzSpacing.sm),
                BarzCard.elevated(
                  child: const Padding(
                    padding: EdgeInsets.all(BarzSpacing.md),
                    child: Text(
                      'Elevated Card (Legacy)',
                      style: TextStyle(color: textOnDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Happening Now Cards',
            child: SizedBox(
              height: 240,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  HappeningNowCard(
                    venue: 'The Brass Monkey',
                    event: 'DJ Momentum',
                    type: 'Deep House',
                    isLive: true,
                    attendees: 127,
                    imageUrl:
                        'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=400&h=600&fit=crop',
                    onTap: () {},
                  ),
                  const SizedBox(width: BarzSpacing.md),
                  HappeningNowCard(
                    venue: 'Warehouse 54',
                    event: 'Techno Nights',
                    type: 'Techno',
                    isLive: true,
                    attendees: 243,
                    imageUrl:
                        'https://images.unsplash.com/photo-1598387993281-cecf8b71a8f8?w=400&h=600&fit=crop',
                    onTap: () {},
                  ),
                  const SizedBox(width: BarzSpacing.md),
                  HappeningNowCard(
                    venue: 'The Velvet Room',
                    event: 'Jazz Fusion',
                    type: 'Live Jazz',
                    isLive: false,
                    attendees: 56,
                    imageUrl:
                        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&h=600&fit=crop',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Your Spots (Bar Cards)',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: BarzSpacing.sm,
              crossAxisSpacing: BarzSpacing.sm,
              childAspectRatio: 0.85,
              children: [
                BarCard(
                  name: 'The Brass Monkey',
                  type: 'Cocktail Bar',
                  distance: '0.3mi',
                  rating: 4.8,
                  imageUrl:
                      'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=300&h=300&fit=crop',
                  onTap: () {},
                ),
                BarCard(
                  name: 'Warehouse 54',
                  type: 'Nightclub',
                  distance: '0.8mi',
                  rating: 4.6,
                  imageUrl:
                      'https://images.unsplash.com/photo-1566417713940-fe7c737a9ef2?w=300&h=300&fit=crop',
                  onTap: () {},
                ),
                BarCard(
                  name: 'The Velvet Room',
                  type: 'Jazz Lounge',
                  distance: '1.2mi',
                  rating: 4.9,
                  imageUrl:
                      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300&h=300&fit=crop',
                  onTap: () {},
                ),
                BarCard(
                  name: 'Neon District',
                  type: 'Live Music',
                  distance: '0.5mi',
                  rating: 4.7,
                  imageUrl:
                      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&h=300&fit=crop',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Live Pulse (Lovable)',
            child: LivePulse(
              venueName: 'The Foundry',
              energyLevel: 78,
              waitTime: '5 min',
              trendingSince: '11PM',
            ),
          ),
          const SizedBox(height: BarzSpacing.xl),
          _buildSection(
            title: 'Venue Cards (Lovable)',
            child: Column(
              children: [
                VenueCard(
                  name: 'The Foundry',
                  type: 'Industrial Bar',
                  distance: '0.3 mi',
                  crowd: 'Busy',
                  isLive: true,
                  imageUrl:
                      'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=800&h=600&fit=crop',
                  onTap: () {},
                ),
                const SizedBox(height: BarzSpacing.md),
                VenueCard(
                  name: 'Skyline Rooftop',
                  type: 'Cocktail Lounge',
                  distance: '1.2 mi',
                  crowd: 'Moderate',
                  isLive: false,
                  imageUrl:
                      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&h=600&fit=crop',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: barzGold, size: 20),
            const SizedBox(width: BarzSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textOnDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: BarzSpacing.md),
        child,
      ],
    );
  }

  Widget _colorSwatch(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(BarzRadii.md),
            border: Border.all(color: barzDarkMuted, width: 1),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: textSecondary)),
      ],
    );
  }
}
