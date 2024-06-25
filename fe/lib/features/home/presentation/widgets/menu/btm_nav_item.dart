import 'package:barz/features/home/presentation/widgets/menu/animated_bar.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/rive_model.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class BtmNavItem extends StatelessWidget {
  const BtmNavItem(
      {super.key,
      required this.navBar,
      required this.press,
      required this.riveOnInit,
      required this.selectedNav});

  final RiveModel navBar;
  final VoidCallback press;
  final ValueChanged<Artboard> riveOnInit;
  final RiveModel selectedNav;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBar(isActive: selectedNav == navBar),
          SizedBox(
            height: 36,
            width: 36,
            child: Opacity(
              opacity: selectedNav == navBar ? 1 : 0.5,
              child: RiveAnimation.asset(
                navBar.src,
                artboard: navBar.artboard,
                onInit: riveOnInit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
