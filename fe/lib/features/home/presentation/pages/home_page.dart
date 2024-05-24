import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/domain/usecases/home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/home_bloc.dart';
import 'package:barz/features/home/presentation/pages/drinks/drinks_home_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_home_page.dart';
import 'package:barz/features/home/presentation/pages/search/SearchHomePage.dart';
import 'package:barz/features/home/presentation/widgets/menu/menu_widget.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/bottom_nav_model.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/rive_model.dart';
import 'package:barz/shared/presentation/bottom_nav_bar/bottom_nav_bar_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final HomeBloc _bloc = HomeBloc(homeUseCase: getItInjector<HomeUseCase>());
  final List<BottomNavigationModel> bottomNavItems = [
    BottomNavigationModel(
      const DrinksHomePage(),
      RiveModel(
          src: "assets/animated-icons.riv",
          artboard: "RULES",
          stateMachineName: "State Machine 1"),
    ),
    BottomNavigationModel(
      const SearchHomePage(),
      RiveModel(
          src: "assets/animated-icons.riv",
          artboard: "SEARCH",
          stateMachineName: "SEARCH_Interactivity"),
    ),
    BottomNavigationModel(
      const ProfileHomePage(),
      RiveModel(
          src: "assets/animated-icons.riv",
          artboard: "USER",
          stateMachineName: "USER_Interactivity"),
    ),
  ];

  late AnimationController _drawerSlideController;

  @override
  void initState() {
    super.initState();
    _drawerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _drawerSlideController.dispose();
    super.dispose();
  }

  bool _isDrawerOpen() {
    return _drawerSlideController.value == 1.0;
  }

  bool _isDrawerOpening() {
    return _drawerSlideController.status == AnimationStatus.forward;
  }

  bool _isDrawerClosed() {
    return _drawerSlideController.value == 0.0;
  }

  void _toggleDrawer() {
    if (_isDrawerOpen() || _isDrawerOpening()) {
      _drawerSlideController.reverse();
    } else {
      _drawerSlideController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildContent(),
          _buildDrawer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: AnimatedBuilder(
        animation: _drawerSlideController,
        builder: (context, child) {
          return IconButton(
            onPressed: _toggleDrawer,
            icon: _isDrawerOpen() || _isDrawerOpening()
                ? const Icon(
                    Icons.clear,
                    color: Colors.black,
                  )
                : const ImageIcon(
                    AssetImage("images/menu_icon.png"),
                    color: Colors.black,
                  ),
          );
        },
      ),
      title: Text(
        AppLocalizations.of(context)!.app_title,
        style: TextStyle(
          fontFamily: 'JuliusSansOne',
          fontSize: 24.sp,
        ),
      ),
      titleSpacing: 24,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0.0,
    );
  }

  Widget _buildContent() {
    return ContainerBottomNavBarAnimated(pageItems: bottomNavItems);
  }

  Widget _buildDrawer() {
    return AnimatedBuilder(
      animation: _drawerSlideController,
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(-1 * (1.0 - _drawerSlideController.value), 0.0),
          child: _isDrawerClosed() ? const SizedBox() : const Menu(),
        );
      },
    );
  }
}
