import 'package:barz/shared/domain/models/card_type_model.dart';
import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:barz/shared/presentation/widget/title_subtitle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              alignment: Alignment.topCenter,
              margin: const EdgeInsets.only(top: 16),
              child: Text(
                AppLocalizations.of(context)!.app_title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JuliusSansOne',
                  fontSize: 24.sp,
                ),
              ),
            ),
            TitleSubtitleWidget(
              title: AppLocalizations.of(context)!.meet_our_parteners,
              subtitle:
                  AppLocalizations.of(context)!.here_are_the_closest_partners,
            ),
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
              cardsType: CardType.rectangular,
            ),
            TitleSubtitleWidget(
              title: AppLocalizations.of(context)!.most_wanted,
              subtitle:
                  AppLocalizations.of(context)!.want_an_specific_drink,
            ),
            HorizontalSlidingCards(
              list: [
                ParallaxRecipeUiModel(
                  imageUrl: "moscowmule.jpeg",
                  name: "Moscow Mule",
                ),
                ParallaxRecipeUiModel(
                  imageUrl: "caipirinha.jpeg",
                  name: "Caipirinha",
                ),
                ParallaxRecipeUiModel(
                  imageUrl: "pinacolada.jpeg",
                  name: "Piña Colada",
                ),
              ],
              cardsType: CardType.circle,
            ),
          ],
        ),
      ),
    );
  }
}
