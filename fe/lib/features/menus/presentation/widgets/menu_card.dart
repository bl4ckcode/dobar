import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/presentation/widget/animated_gif_widget.dart';
import 'package:flutter/material.dart';

import '../../../menus/domain/models/menu/item_menu_ui_model.dart';

class BarMenuCard extends StatelessWidget {
  final ItemMenuUiModel item;

  const BarMenuCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColorDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Image.network(item.img),
          Text(item.title, style: TextStyle(color: Colors.white)),
          Text(item.price, style: TextStyle(color: Colors.white)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          AnimatedGifWidget(gifAssetPath: 'assets/icons/icons8-add.gif'),
        ],
      ),
    );
  }
}
