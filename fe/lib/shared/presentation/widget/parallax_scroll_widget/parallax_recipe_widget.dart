import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_list_item_widget.dart';
import 'package:flutter/widgets.dart';

class ParallaxRecipe extends StatelessWidget {
  const ParallaxRecipe({super.key, required this.list});

  final List<ParallaxRecipeUiModel> list;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 120, // <-- you should put some value here
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (context, index) {
              return HorizontalListItem(
                  imageUrl: list[index].imageUrl,
                  name: list[index].name,
                  description: list[index].description);
            },
          ),
        ),
      ],
    ));
  }
}
