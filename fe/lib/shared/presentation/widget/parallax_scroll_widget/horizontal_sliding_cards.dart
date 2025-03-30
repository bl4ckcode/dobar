import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/card_circle.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/card_type_model.dart';
import 'card_rectangle.dart';

class HorizontalSlidingCards extends StatefulWidget {
  const HorizontalSlidingCards({
    super.key,
    required this.list,
    required this.cardsType,
    required this.onCardTap,
  });

  final List<ParallaxRecipeUiModel> list;
  final CardType cardsType;
  final void Function(ParallaxRecipeUiModel) onCardTap;

  @override
  State<HorizontalSlidingCards> createState() => _HorizontalSlidingCardsState();
}

class _HorizontalSlidingCardsState extends State<HorizontalSlidingCards> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: widget.cardsType.cardHeight(),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.list.length,
        itemBuilder: (context, index) {
          final ParallaxRecipeUiModel bar = widget.list[index];
          final card = widget.cardsType == CardType.circle ? CircleCard(bar: bar) : RectangleCard(bar: bar);
          return Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: GestureDetector(
              onTap: () {
                // Notify parent when the card is tapped
                widget.onCardTap(bar);
              },
              child: card,
            ),
          );
        },
      ),
    );
  }
}
