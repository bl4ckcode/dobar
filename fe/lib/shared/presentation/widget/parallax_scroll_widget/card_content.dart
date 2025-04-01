import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:flutter/material.dart';

class CardContent extends StatelessWidget {
  final ParallaxRecipeUiModel parallaxRecipeUiModel;

  const CardContent({super.key, required this.parallaxRecipeUiModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          parallaxRecipeUiModel.name.length > 15
              ? '${parallaxRecipeUiModel.name.substring(
                  0,
                  15,
                )}...'
              : parallaxRecipeUiModel.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: <Widget>[
            Text(
              parallaxRecipeUiModel.adress.length > 15
                  ? '${parallaxRecipeUiModel.adress.substring(
                      0,
                      15,
                    )}...'
                  : parallaxRecipeUiModel.adress,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(),
            Text(
              parallaxRecipeUiModel.approximateLocation,
              style: const TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 14,
              ),
            ),
          ],
        )
      ],
    );
  }
}
