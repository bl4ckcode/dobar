import 'package:barz/core/router/router.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/location_handler.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_event.dart';
import 'package:barz/features/home/presentation/bloc/drinks/drinks_home_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/domain/models/card_type_model.dart';
import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/loading_util.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:barz/shared/presentation/widget/title_subtitle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:location/location.dart';

class DrinksHomePage extends StatefulWidget {
  const DrinksHomePage({super.key});

  @override
  State<DrinksHomePage> createState() => _DrinksHomePageState();
}

class _DrinksHomePageState extends State<DrinksHomePage> {
  late DrinksHomeBloc _drinksHomeBloc;
  LocationData? _currentLocation;
  bool _isLocationFetched = false;

  @override
  void initState() {
    super.initState();
    _drinksHomeBloc = DrinksHomeBloc(
      drinksHomeUseCase: getItInjector<DrinksHomeUseCase>(),
    );
    _fetchLocationAndLoadPartners();
  }

  Future<void> _fetchLocationAndLoadPartners() async {
    try {
      final Location location = Location();
      final currentLocation = await location.getLocation();

      setState(() {
        _currentLocation = currentLocation;
        _isLocationFetched = true;
      });

      // Dispatch the event with location parameters:
      _drinksHomeBloc.add(
        DrinksHomeLoadPartners(
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          maxDistance: 35000,
        ),
      );
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
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
        child: BlocConsumer<DrinksHomeBloc, DrinksHomeState>(
          bloc: _drinksHomeBloc,
          listener: (context, state) {
            if (state is Loading) {
              LoadingUtil.showLoadingDialog(context);
            } else if (state is Success) {
              Navigator.of(context).pop(); // Dismiss loading dialog
            } else if (state is Failure) {
              Navigator.of(context).pop();
              // Optionally show error message (e.g., using a SnackBar)
            }
          },
          builder: (context, state) {
            // Build UI based on state
            if (state is Success) {
              // The Success state now holds a list of ParallaxRecipeUiModel
              return _buildContent(context, state.partners);
            }
            // While loading or if there's an error, you can show a placeholder
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<ParallaxRecipeUiModel> partners) {
    return SingleChildScrollView(
      child: Column(
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
            list: partners, // Use the UI model list from the state
            cardsType: CardType.rectangular,
            onCardTap: (ParallaxRecipeUiModel selectedBar) {
              AppRouter.route(RouteSettings(
                name: AppRouter.partnerMenu,
                arguments: selectedBar.id,
              ));
            },
          ),
          TitleSubtitleWidget(
            title: AppLocalizations.of(context)!.most_wanted,
            subtitle: AppLocalizations.of(context)!.want_an_specific_drink,
          ),
          HorizontalSlidingCards(
            list: [
              // You can build another list for "most wanted" drinks if available,
              // or use partners list with a different UI model mapping.
              ParallaxRecipeUiModel(
                id: 0,
                imageUrl: "moscowmule.jpeg",
                name: "Moscow Mule",
              ),
              ParallaxRecipeUiModel(
                id: 1,
                imageUrl: "caipirinha.jpeg",
                name: "Caipirinha",
              ),
              ParallaxRecipeUiModel(
                id: 2,
                imageUrl: "pinacolada.jpeg",
                name: "Piña Colada",
              ),
            ],
            cardsType: CardType.circle,
            onCardTap: (ParallaxRecipeUiModel selectedBar) {},
          ),
        ],
      ),
    );
  }
}
