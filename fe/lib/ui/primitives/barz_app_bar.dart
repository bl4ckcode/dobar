import 'package:flutter/material.dart';
import '../../core/utils/constant/colors.dart';
import '../../core/utils/constant/styles.dart';

class BarzAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const BarzAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: barzBlack,
      title: Text(
        title,
        style: BarzTextStyles.headline.copyWith(color: barzYellow),
      ),
      actions: actions,
      centerTitle: true,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
