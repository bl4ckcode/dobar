import 'package:barz/features/home/presentation/widgets/menu/animated_bar.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/nav_item_model.dart';
import 'package:flutter/material.dart';

class BtmNavItem extends StatelessWidget {
  const BtmNavItem({
    super.key,
    required this.navItem,
    required this.press,
    required this.isSelected,
  });

  final NavItemModel navItem;
  final VoidCallback press;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBar(isActive: isSelected),
          SizedBox(
            height: 36,
            width: 36,
            child: Icon(
              isSelected ? navItem.displayIcon : navItem.icon,
              size: 28,
              color: isSelected ? Colors.black : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
