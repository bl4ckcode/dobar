import 'package:flutter/material.dart';

import '../../../domain/models/parallax_recipe_ui_model.dart';
import 'card_content.dart';

class CircleCard extends StatelessWidget {
  const CircleCard({
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
        // Image
        ClipOval(
          child: SizedBox.fromSize(
            size: const Size.fromRadius(48),
            child: Image.asset(
              'assets/images/${bar.imageUrl}',
              fit: BoxFit.fill,
            ),
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