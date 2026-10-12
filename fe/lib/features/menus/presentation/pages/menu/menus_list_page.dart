import 'package:flutter/material.dart';

import '../../../domain/models/menu/item_menu_ui_model.dart';
import '../../../domain/models/menu/menu_type.dart';
import '../../../../menus/presentation/widgets/menu_card.dart';

class BarMenusList extends StatefulWidget {
  const BarMenusList({super.key, required this.list, required this.menuType});

  final List<ItemMenuUiModel> list;
  final MenuType menuType;

  @override
  State<BarMenusList> createState() => _BarMenusListState();
}

class _BarMenusListState extends State<BarMenusList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 300, // Adjust as needed
      child: AnimatedList(
        key: _listKey,
        scrollDirection: Axis.horizontal,
        initialItemCount: widget.list.length,
        itemBuilder: (context, index, animation) {
          return _buildMenuItem(widget.list[index], animation);
        },
      ),
    );
  }

  Widget _buildMenuItem(ItemMenuUiModel item, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(animation),
        child: BarMenuCard(item: item),
      ),
    );
  }
}
