import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/widgets/menu/btm_nav_item.dart';
import 'package:barz/features/home/presentation/widgets/menu/menu_btn.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/menu_model.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/nav_item_model.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import '../widgets/menu/side_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static bool _hasPromptedBiometrics = false;
  late AnimationController _drawerSlideController;
  late Animation<double> animation;
  late Animation<double> scalAnimation;

  bool isSideBarOpen = false;
  late Menu selectedBottonNav;
  late Menu selectedSideMenu;

  @override
  void initState() {
    super.initState();
    selectedBottonNav = homeBottomNavItems.first;
    selectedSideMenu = sidebarMenus.first;

    _verifyBiometricsOnStartup();

    _drawerSlideController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          setState(() {});
        });

    scalAnimation = Tween<double>(begin: 1, end: 0.8).animate(
      CurvedAnimation(
        parent: _drawerSlideController,
        curve: Curves.fastOutSlowIn,
      ),
    );
    animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawerSlideController,
        curve: Curves.fastOutSlowIn,
      ),
    );
  }

  @override
  void dispose() {
    _drawerSlideController.dispose();
    super.dispose();
  }

  Future<void> _verifyBiometricsOnStartup() async {
    if (_hasPromptedBiometrics) return;
    final biometryService = getItInjector<BiometryService>();
    if (!biometryService.isEnabled) return;

    _hasPromptedBiometrics = true;
    final available = await biometryService.isAvailable;
    if (!available) return;

    final authenticated = await biometryService.authenticate(
      'Authenticate to continue',
    );
    if (!authenticated && mounted) {
      AppRoute.login.go(context);
    }
  }

  void updateSelectedBtmNav(Menu bottomNavigationModel) {
    if (selectedBottonNav != bottomNavigationModel) {
      setState(() {
        selectedBottonNav = bottomNavigationModel;
      });
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
                1 * animation.value - 30 * (animation.value) * pi / 180,
              ),
            child: Transform.translate(
              offset: Offset(animation.value * 265, 0),
              child: Transform.scale(
                scale: scalAnimation.value,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
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
              isOpen: isSideBarOpen,
              press: () {
                if (_drawerSlideController.value == 0) {
                  _drawerSlideController.forward();
                } else {
                  _drawerSlideController.reverse();
                }

                setState(() {
                  isSideBarOpen = !isSideBarOpen;
                });
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Transform.translate(
        offset: Offset(0, 100 * animation.value),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.only(
              left: 12,
              top: 12,
              right: 12,
              bottom: 12,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: mainColor.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor2.withValues(alpha: 0.8),
                  offset: const Offset(0, 20),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ...List.generate(homeBottomNavItems.length, (index) {
                  NavItemModel navItem = homeBottomNavItems[index].navItem;
                  bool isSelected =
                      selectedBottonNav == homeBottomNavItems[index];
                  return BtmNavItem(
                    navItem: navItem,
                    isSelected: isSelected,
                    press: () {
                      updateSelectedBtmNav(homeBottomNavItems[index]);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
