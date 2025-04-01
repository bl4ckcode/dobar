import 'package:flutter/material.dart';

import '../../../domain/models/parallax_recipe_ui_model.dart';
import 'card_content.dart';

class RectangleCard extends StatelessWidget {
  const RectangleCard({
    super.key,
    required this.bar,
  });

  final ParallaxRecipeUiModel bar;

  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetworkImage = _isValidUrl(bar.imageUrl);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: isNetworkImage
              ? Image.network(
                  bar.imageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.fill,
                )
              : Image.asset(
                  'assets/images/cup_placeholder.jpg',
                  width: 150,
                  height: 150,
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
