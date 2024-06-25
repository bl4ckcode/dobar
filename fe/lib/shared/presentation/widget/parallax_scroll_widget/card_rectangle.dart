import 'package:flutter/material.dart';

import '../../../domain/models/parallax_recipe_ui_model.dart';
import 'card_content.dart';

class RectangleCard extends StatelessWidget {
  const RectangleCard({
    super.key,
    required this.bar,
  });

  final ParallaxRecipeUiModel bar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            width: 150,
            height: 150,
            'assets/images/${bar.imageUrl}',
            fit: BoxFit.fill,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        SizedBox(
          width: 150,
          child: CardContent(parallaxRecipeUiModel: bar),
        )
      ],
    );
  }
}