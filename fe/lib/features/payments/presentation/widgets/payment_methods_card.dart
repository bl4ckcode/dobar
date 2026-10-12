import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';

import '../../domain/models/checkout_models.dart';
import 'add_new_card_workflow.dart';
import 'saved_cards_list.dart';
import 'payment_options_grid.dart';
import 'digital_wallets_section.dart';

class PaymentMethodsCard extends StatefulWidget {
  final List<SavedCard> savedCards;
  final String? selectedCardId;
  final Function(String) onSelectCard;
  final Function(Map<String, String>) onAddCardComplete;
  final List<PaymentOptionItem> paymentOptions;
  final VoidCallback onApplePay;
  final VoidCallback onGooglePay;
  final bool isDark;
  final bool isLoadingCards;

  const PaymentMethodsCard({
    super.key,
    required this.savedCards,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.onAddCardComplete,
    required this.paymentOptions,
    required this.onApplePay,
    required this.onGooglePay,
    required this.isDark,
    this.isLoadingCards = false,
  });

  @override
  State<PaymentMethodsCard> createState() => _PaymentMethodsCardState();
}

class _PaymentMethodsCardState extends State<PaymentMethodsCard> {
  late bool _isExpanded;
  bool _showAddCard = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.savedCards.isNotEmpty;
  }

  @override
  void didUpdateWidget(PaymentMethodsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedCards.isEmpty && widget.savedCards.isNotEmpty) {
      _isExpanded = true;
    }
  }

  void _handleAddCardComplete(Map<String, String> cardData) {
    setState(() {
      _showAddCard = false;
    });
    widget.onAddCardComplete(cardData);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgColor = widget.isDark ? barzDarkLight : surfaceWhite;
    final textColor = widget.isDark ? textOnDark : textPrimary;
    final mutedColor = textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (!_isExpanded) _showAddCard = false;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: barzGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      color: barzGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.checkout_payment_method,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (widget.isLoadingCards)
                          Text(
                            l10n.loading,
                            style: TextStyle(fontSize: 13, color: mutedColor),
                          )
                        else
                          Text(
                            widget.savedCards.isNotEmpty
                                ? '${widget.savedCards.length} ${widget.savedCards.length > 1 ? l10n.payment_method_card : l10n.payment_credit_card}'
                                : l10n.payment_method,
                            style: TextStyle(fontSize: 13, color: mutedColor),
                          ),
                      ],
                    ),
                  ),
                  if (widget.selectedCardId != null &&
                      widget.savedCards.isNotEmpty &&
                      !widget.selectedCardId!.startsWith('__'))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '•••• ${widget.savedCards.where((c) => c.id == widget.selectedCardId).firstOrNull?.last4 ?? ''}',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: mutedColor,
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: widget.isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFEEEEEE),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: widget.isLoadingCards
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : AnimatedCrossFade(
                          firstChild: AddNewCardWorkflow(
                            isDark: widget.isDark,
                            onClose: () =>
                                setState(() => _showAddCard = false),
                            onComplete: _handleAddCardComplete,
                          ),
                          secondChild: Column(
                            children: [
                              if (widget.savedCards.isNotEmpty)
                                SavedCardsList(
                                  cards: widget.savedCards,
                                  selectedCardId: widget.selectedCardId,
                                  onSelectCard: widget.onSelectCard,
                                  onAddCard: () =>
                                      setState(() => _showAddCard = true),
                                  isDark: widget.isDark,
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _showAddCard = true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: widget.isDark
                                              ? const Color(0xFF444444)
                                              : const Color(0xFFDDDDDD),
                                          style: BorderStyle.solid,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.credit_card,
                                            color: mutedColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.payment_method_card,
                                            style: TextStyle(
                                              color: mutedColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              const SizedBox(height: 16),
                              ...widget.paymentOptions.map((option) {
                                final isSelected = widget.selectedCardId ==
                                    (option.label.contains('Nubank')
                                        ? '__nubank__'
                                        : '__pix__');
                                return GestureDetector(
                                  onTap: option.onTap,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: widget.isDark
                                          ? const Color(0xFF2B2B2B)
                                          : const Color(0xFFF9F9F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? barzGold
                                            : (widget.isDark
                                                ? const Color(0xFF444444)
                                                : const Color(0xFFDDDDDD)),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(option.icon,
                                            color: option.iconColor),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            option.label,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? barzGold
                                                  : mutedColor,
                                              width: 2,
                                            ),
                                            color: isSelected
                                                ? barzGold
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  size: 16, color: barzDark)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 24),
                              DigitalWalletsSection(
                                onApplePay: widget.onApplePay,
                                onGooglePay: widget.onGooglePay,
                              ),
                            ],
                          ),
                          crossFadeState: _showAddCard
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 300),
                        ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
