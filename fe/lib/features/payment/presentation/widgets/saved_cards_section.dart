import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/payment_models.dart';

class SavedCardsSection extends StatelessWidget {
  final List<SavedCard> cards;
  final String? selectedCardId;
  final ValueChanged<String> onSelectCard;
  final VoidCallback onAddCard;

  const SavedCardsSection({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.onAddCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved Cards',
            style: TextStyle(
              color: isDark ? textOnDark : textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(right: 16),
              itemCount: cards.length + 1,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == cards.length) {
                  return _buildAddCardButton(isDark);
                }
                return _buildCardTile(cards[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(SavedCard card, bool isDark) {
    final isSelected = card.id == selectedCardId;

    return GestureDetector(
      onTap: () => onSelectCard(card.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? barzGold : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: barzGold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: barzDark.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBrandIcon(card.brand),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: barzGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: barzDark, size: 14),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•••• ${card.last4}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expires ${card.expiry}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandIcon(CardBrand brand) {
    final config = _brandConfig[brand]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: config['gradient'] as Gradient?,
        color: config['color'] as Color?,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config['text'] as String,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static const Map<CardBrand, Map<String, dynamic>> _brandConfig = {
    CardBrand.visa: {'color': Color(0xFF1A1F71), 'text': 'VISA'},
    CardBrand.mastercard: {
      'gradient': LinearGradient(
        colors: [Color(0xFFEF5350), Color(0xFFFFB300)],
      ),
      'text': 'MC',
    },
    CardBrand.elo: {'color': Color(0xFFFFD700), 'text': 'ELO'},
    CardBrand.amex: {'color': Color(0xFF2196F3), 'text': 'AMEX'},
    CardBrand.nubank: {'color': Color(0xFF8A05BE), 'text': 'NU'},
  };

  Widget _buildAddCardButton(bool isDark) {
    return GestureDetector(
      onTap: onAddCard,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF666666) : textSecondary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                color: isDark ? const Color(0xFF888888) : textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add new card',
              style: TextStyle(
                color: isDark ? const Color(0xFF888888) : textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
