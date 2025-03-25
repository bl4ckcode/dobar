import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_state.dart';
import 'package:barz/shared/domain/models/card_type_model.dart';
import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/loading_util.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:barz/shared/presentation/widget/title_subtitle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DrinksHomePage extends StatefulWidget {
  const DrinksHomePage({super.key});

  @override
  State<DrinksHomePage> createState() => _DrinksHomePageState();
}

class _DrinksHomePageState extends State<DrinksHomePage> {
  late DrinksHomeBloc _drinksHomeBloc;

  @override
  void initState() {
    super.initState();
    _drinksHomeBloc = DrinksHomeBloc(
      drinksHomeUseCase: getItInjector<DrinksHomeUseCase>(),
    );
  }

  @override
  void dispose() {
    _drinksHomeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PopScope(
          onPopInvokedWithResult: (left, right) {},
          child: BlocListener<DrinksHomeBloc, DrinksHomeState>(
            bloc: _drinksHomeBloc,
            listener: (context, state) {
              if (state is Loading) {
                LoadingUtil.showLoadingDialog(context);
              } else if (state is Success) {
                Navigator.of(context).pop();


              } else if (state is Failure) {
                Navigator.of(context).pop();

              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.max,
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
                  subtitle: AppLocalizations.of(context)!
                      .here_are_the_closest_partners,
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
        ),
      ),
    );
  }
}
