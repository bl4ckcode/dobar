import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/menu_model.dart';
import 'package:barz/shared/presentation/widget/bottom_nav_bar/highlight_nav_bar_animated_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  int selctedNavIndex = 0;

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
                final navItem = widget.pageItems[index].navItem;
                final isSelected = selctedNavIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selctedNavIndex = index;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HighlightAnimatedBar(isActive: isSelected),
                      SizedBox(
                        height: 32.h,
                        width: 32.w,
                        child: Icon(
                          isSelected ? navItem.displayIcon : navItem.icon,
                          size: 28.sp,
                          color: isSelected ? Colors.black : Colors.black54,
                        ),
                      ),
                      Text(
                        navItem.title,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isSelected ? Colors.black : Colors.black54,
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
