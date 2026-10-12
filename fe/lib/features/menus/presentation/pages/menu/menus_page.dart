import 'package:barz/core/utils/constant/colors.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/menu/item_menu_ui_model.dart';
import '../../../domain/models/menu/menu_type.dart';

import 'menus_list_page.dart';

class MenusPage extends StatefulWidget {
  const MenusPage({super.key});

  @override
  State<MenusPage> createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  late List<ItemMenuUiModel> menuItems;
  late MenuType menuType;

  @override
  void initState() {
    super.initState();
    // Initialize menuItems and menuType with your data
    menuItems = [
      // Populate with ItemMenuUiModel instances
    ];
    menuType = MenuType.food; // Example: Set the appropriate menu type
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
            left: 0,
            top: 0,
            child: BarMenusList(list: menuItems, menuType: menuType),
          ),
        ],
      ),
    );
  }
}
