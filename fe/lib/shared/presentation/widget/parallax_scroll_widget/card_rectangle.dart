import 'package:flutter/material.dart';
import 'package:barz/shared/presentation/widget/safe_network_image.dart';

import '../../../domain/models/parallax_recipe_ui_model.dart';
import 'card_content.dart';

class RectangleCard extends StatelessWidget {
  const RectangleCard({super.key, required this.bar});

  final ParallaxRecipeUiModel bar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SafeNetworkImage(
          imageUrl: bar.imageUrl,
          width: 150,
          height: 150,
          fit: BoxFit.fill,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 4),
        SizedBox(width: 150, child: CardContent(parallaxRecipeUiModel: bar)),
      ],
    );
  }
}
