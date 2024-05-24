import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/parallax_recipe_widget.dart';
import 'package:flutter/material.dart';

class DrinksHomePage extends StatefulWidget {
  const DrinksHomePage({Key? key}) : super(key: key);

  @override
  State<DrinksHomePage> createState() => _DrinksHomePageState();
}

class _DrinksHomePageState extends State<DrinksHomePage> {
  @override
  Widget build(BuildContext context) {
    return ParallaxRecipe(
      list: [
        ParallaxRecipeUiModel(
            imageUrl:
                "https://portalbelohorizonte.com.br/sites/default/files/arquivos/comer-e-beber/2019-10/47574143_2198300353547845_1259315648484343808_n.jpg",
            name: "Porcao",
            description: "Porcao 4km distancia"),
      ],
    );
  }
}
