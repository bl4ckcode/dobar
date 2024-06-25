import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:barz/shared/presentation/widget/title_subtitle_widget.dart';
import 'package:flutter/material.dart';

class DrinksHomePage extends StatefulWidget {
  const DrinksHomePage({super.key});

  @override
  State<DrinksHomePage> createState() => _DrinksHomePageState();
}

class _DrinksHomePageState extends State<DrinksHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const TitleSubtitleWidget(),
          HorizontalSlidingCards(
            list: [
              ParallaxRecipeUiModel(
                  imageUrl: "porcao.jpg",
                  name: "Porcao",
                  adress: "Av Raja Gabaglia, 300",
                  approximateLocation: "4km"),
              ParallaxRecipeUiModel(
                imageUrl: "choppdafabrica.jpeg",
                name: "Chopp da Fabrica",
                adress: "Av. Otacilio Negrão, 106",
                approximateLocation: "5km",
              ),
              ParallaxRecipeUiModel(
                imageUrl: "mascate.jpeg",
                name: "Mascate",
                adress: "Rua Sergipe, 502!",
                approximateLocation: "3km",
              ),
            ],
          )
          ],
        ),
      ),
    );
  }
}

