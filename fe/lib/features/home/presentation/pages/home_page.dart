import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/domain/usecases/home_usecase.dart';
import 'package:barz/features/home/presentation/bloc/home_bloc.dart';
import 'package:barz/features/home/presentation/pages/drinks/drinks_home_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_home_page.dart';
import 'package:barz/features/home/presentation/pages/search/SearchHomePage.dart';
import 'package:barz/features/home/presentation/widgets/menu/btm_nav_item.dart';
import 'package:barz/features/home/presentation/widgets/menu/menu_btn.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/menu_model.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/rive_model.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:rive/rive.dart';

import '../../../../core/utils/rive/rive_utils.dart';
import '../widgets/menu/side_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final HomeBloc _bloc = HomeBloc(homeUseCase: getItInjector<HomeUseCase>());

  final List<Menu> bottomNavItems = [
    Menu(
      const DrinksHomePage(),
      RiveModel(
          src: "assets/RiveAssets/icons.riv",
          artboard: "HOME",
          stateMachineName: "HOME_interactivity"),
    ),
    Menu(
      const SearchHomePage(),
      RiveModel(
          src: "assets/RiveAssets/icons.riv",
          artboard: "SEARCH",
          stateMachineName: "SEARCH_Interactivity"),
    ),
    Menu(
      const ProfileHomePage(),
      RiveModel(
          src: "assets/RiveAssets/icons.riv",
          artboard: "USER",
          stateMachineName: "USER_Interactivity"),
    ),
  ];

  late SMIBool isMenuOpenInput;

  late AnimationController _drawerSlideController;
  late Animation<double> animation;
  late Animation<double> scalAnimation;

  bool isSideBarOpen = false;
  late Menu selectedBottonNav;
  late Menu selectedSideMenu;

  @override
  void initState() {
    super.initState();
    selectedBottonNav = bottomNavItems.first;
    selectedSideMenu = sidebarMenus.first;

    _drawerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(
        () {
          setState(() {});
        },
      );

    scalAnimation = Tween<double>(begin: 1, end: 0.8).animate(CurvedAnimation(
        parent: _drawerSlideController, curve: Curves.fastOutSlowIn));
    animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _drawerSlideController, curve: Curves.fastOutSlowIn));
  }

  @override
  void dispose() {
    _drawerSlideController.dispose();
    super.dispose();
  }

  void updateSelectedBtmNav(Menu bottomNavigationModel) {
    if (selectedBottonNav != bottomNavigationModel) {
      setState(
        () {
          selectedBottonNav = bottomNavigationModel;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor2,
      body: Stack(
        children: [
          AnimatedPositioned(
            width: 288,
            height: MediaQuery.of(context).size.height,
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            left: isSideBarOpen ? 0 : -288,
            top: 0,
            child: const SideBar(),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(
                  1 * animation.value - 30 * (animation.value) * pi / 180),
            child: Transform.translate(
              offset: Offset(animation.value * 265, 0),
              child: Transform.scale(
                scale: scalAnimation.value,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(24),
                  ),
                  child: selectedBottonNav.page,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            left: isSideBarOpen ? 220 : 0,
            top: 16,
            child: MenuBtn(
              press: () {
                isMenuOpenInput.value = !isMenuOpenInput.value;

                if (_drawerSlideController.value == 0) {
                  _drawerSlideController.forward();
                } else {
                  _drawerSlideController.reverse();
                }

                setState(
                  () {
                    isSideBarOpen = !isSideBarOpen;
                  },
                );
              },
              riveOnInit: (artboard) {
                final controller = StateMachineController.fromArtboard(
                    artboard, "State Machine");
                artboard.addController(controller!);

                isMenuOpenInput =
                    controller.findInput<bool>("isOpen") as SMIBool;
                isMenuOpenInput.value = true;
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Transform.translate(
        offset: Offset(0, 100 * animation.value),
        child: SafeArea(
            child: Container(
          padding:
              const EdgeInsets.only(left: 12, top: 12, right: 12, bottom: 12),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: mainColor.withOpacity(0.8),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: backgroundColor2.withOpacity(0.3),
                offset: const Offset(0, 20),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...List.generate(
                bottomNavItems.length,
                (index) {
                  RiveModel navBar = bottomNavItems[index].rive;
                  return BtmNavItem(
                    navBar: navBar,
                    press: () {
                      RiveUtils.chnageSMIBoolState(navBar.status!);
                      updateSelectedBtmNav(bottomNavItems[index]);
                    },
                    riveOnInit: (artboard) {
                      navBar.status = RiveUtils.getRiveInput(artboard,
                          stateMachineName: navBar.stateMachineName);
                    },
                    selectedNav: selectedBottonNav.rive,
                  );
                },
              )
            ],
          ),
        )),
      ),
    );
  }
}
