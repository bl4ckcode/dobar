import 'package:barz/core/utils/constant/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TitleSubtitleWidget extends StatelessWidget {
  const TitleSubtitleWidget({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget titleWidget = Text(
      title,
      style: theme.textTheme.headlineMedium!.copyWith(
        color: mainColor,
        fontWeight: FontWeight.bold,
      ),
    );

    Widget subtitleWidget = Text(
      subtitle,
      style: const TextStyle(fontSize: 14),
    ).animate().scale(duration: 800.ms, alignment: Alignment.centerLeft);

    // here's an interesting little trick, we can nest Animate to have
    // effects that repeat and ones that only run once on the same item:
    titleWidget = titleWidget
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 3.seconds, color: lighterBluer)
        .animate() // this wraps the previous Animate in another Animate
        .fadeIn(duration: 3.seconds, curve: Curves.easeOutQuad)
        .slide();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: titleWidget,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 16),
              child: subtitleWidget,
            ),
          ],
        ),
      ],
    );
  }
}
