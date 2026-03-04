import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';
import '../../domain/models/payment_models.dart';

class SavedCardsList extends StatelessWidget {
  final List<SavedCard> cards;
  final String? selectedCardId;
  final Function(String) onSelectCard;
  final VoidCallback onAddCard;
  final bool isDark;

  const SavedCardsList({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.onAddCard,
    required this.isDark,
  });

  Color _getBrandColor(CardBrand brand) {
    switch (brand) {
      case CardBrand.visa:
        return Colors.blue.shade600;
      case CardBrand.mastercard:
        return Colors.orange.shade500;
      case CardBrand.elo:
        return Colors.yellow.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  String _getBrandText(CardBrand brand) {
    switch (brand) {
      case CardBrand.visa:
        return 'VISA';
      case CardBrand.mastercard:
        return 'MC';
      case CardBrand.elo:
        return 'ELO';
      default:
        return 'CARD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? textOnDark : textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Saved Cards',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length + 1,
            itemBuilder: (context, index) {
              if (index < cards.length) {
                final card = cards[index];
                final isSelected = card.id == selectedCardId;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => onSelectCard(card.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 170,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2B2B2B), Color(0xFF141414)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: barzGold, width: 2)
                            : Border.all(color: Colors.transparent, width: 2),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: barzGold.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getBrandColor(card.brand),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getBrandText(card.brand),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: barzGold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: barzDark,
                                    size: 12,
                                  ),
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
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expires ${card.expiry}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return GestureDetector(
                  onTap: onAddCard,
                  child: Container(
                    width: 170,
                    decoration: BoxDecoration(
                      color: isDark ? barzDarkLight : surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF444444)
                            : const Color(0xFFDDDDDD),
                        width: 2,
                        style: BorderStyle
                            .solid, // Using solid visually simulating dashed if needed, but solid is cleaner in Flutter unless dashed package is used.
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? textSecondary : textSecondary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: isDark ? textSecondary : textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add new card',
                          style: TextStyle(
                            color: isDark ? textSecondary : textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
