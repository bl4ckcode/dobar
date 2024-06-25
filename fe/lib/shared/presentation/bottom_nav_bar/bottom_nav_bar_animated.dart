import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/menu_model.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/rive_model.dart';
import 'package:barz/shared/presentation/widget/bottom_nav_bar/highlight_nav_bar_animated_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart';

class ContainerBottomNavBarAnimated extends StatefulWidget {
  const ContainerBottomNavBarAnimated({required this.pageItems, super.key});

  final List<Menu> pageItems;

  @override
  State<ContainerBottomNavBarAnimated> createState() =>
      _ContainerBottomNavBarAnimatedState();
}

class _ContainerBottomNavBarAnimatedState
    extends State<ContainerBottomNavBarAnimated> {
  Color bottonNavBgColor = bottomNavigationBarColor;

  List<SMIBool?> riveIconInputs = [];
  List<StateMachineController?> controllers = [];
  int selctedNavIndex = 0;

  void riveInit(Artboard artboard, {required String stateMachineName}) {
    StateMachineController? stateMachineController =
        StateMachineController.fromArtboard(artboard, stateMachineName);

    if (stateMachineController != null) {
      artboard.addController(stateMachineController);
      controllers.add(stateMachineController);

      SMIBool? active = stateMachineController.findInput<bool>('active') as SMIBool?;
      riveIconInputs.add(active);
    }
  }

  void animateTheIcon(int index) {
    riveIconInputs[index]?.change(true);
    Future.delayed(
      const Duration(seconds: 1),
      () {
        riveIconInputs[index]?.change(false);
      },
    );
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.pageItems[selctedNavIndex].page, //Page to display
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72.h,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: mainColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurStyle: BlurStyle.outer,
                blurRadius: 0.1,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              widget.pageItems.length,
              (index) {
                final riveIcon = widget.pageItems[index].rive as RiveModel;
                return GestureDetector(
                  onTap: () {
                    animateTheIcon(index);
                    setState(
                      () {
                        selctedNavIndex = index;
                      },
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HighlightAnimatedBar(isActive: selctedNavIndex == index),
                      SizedBox(
                        height: 32.h,
                        width: 32.w,
                        child: Opacity(
                          opacity: selctedNavIndex == index ? 1 : 0.54,
                          child: RiveAnimation.asset(
                            riveIcon.src,
                            artboard: riveIcon.artboard,
                            onInit: (artboard) {
                              riveInit(artboard,
                                  stateMachineName: riveIcon.stateMachineName);
                            },
                          ),
                        ),
                      ),
                      Text(
                        'Pedidos',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: selctedNavIndex == index ? Colors.black : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
