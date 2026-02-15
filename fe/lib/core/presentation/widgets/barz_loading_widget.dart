import 'package:barz/core/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class BarzLoadingWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const BarzLoadingWidget({super.key, this.size = 50, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: color ?? barzGold,
        size: size,
      ),
    );
  }
}
