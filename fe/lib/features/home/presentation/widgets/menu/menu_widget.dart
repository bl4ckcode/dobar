import 'package:barz/core/utils/constant/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const menuTitles = [
  'Alterar localização',
  'Politica de Reembolso',
  'FAQ',
  'Seja um parceiro'
];
const initialDelayTime = Duration(milliseconds: 50);
const itemSlideTime = Duration(milliseconds: 250);
const staggerTime = Duration(milliseconds: 50);
const buttonDelayTime = Duration(milliseconds: 150);
const buttonTime = Duration(milliseconds: 500);

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<StatefulWidget> createState() => _MenuState();
}

class _MenuState extends State<Menu> with SingleTickerProviderStateMixin {
  final List<Interval> itemSlideIntervals = [];
  late Interval buttonInterval;
  late AnimationController animationController;

  final _animationDuration = initialDelayTime +
      (staggerTime * menuTitles.length) +
      buttonDelayTime +
      buttonTime;

  @override
  void initState() {
    super.initState();

    createAnimationIntervals();

    animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void createAnimationIntervals() {
    for (var i = 0; i < menuTitles.length; ++i) {
      final startTime = initialDelayTime + (staggerTime * i);
      final endTime = startTime + itemSlideTime;
      itemSlideIntervals.add(
        Interval(
          startTime.inMilliseconds / _animationDuration.inMilliseconds,
          endTime.inMilliseconds / _animationDuration.inMilliseconds,
        ),
      );

      final buttonStartTime =
          Duration(milliseconds: (menuTitles.length * 50)) + buttonDelayTime;
      final buttonEndTime = buttonStartTime + buttonTime;

      buttonInterval = Interval(
        buttonStartTime.inMilliseconds / _animationDuration.inMilliseconds,
        buttonEndTime.inMilliseconds / _animationDuration.inMilliseconds,
      );
    }
  }

  Widget buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...buildListItems(),
        const Spacer(),
        buildBottomButton(),
      ],
    );
  }

  List<Widget> buildListItems() {
    final listItems = <Widget>[];

    for (var i = 0; i < menuTitles.length; i++) {
      listItems.add(
        AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            final animationPercent = Curves.easeOut.transform(
              itemSlideIntervals[i].transform(animationController.value),
            );
            final opacity = animationPercent;
            final slideDistance = (1.0 - animationPercent) * 150;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(-1 * slideDistance, 0),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            child: Text(
              menuTitles[i],
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      );
    }

    return listItems;
  }

  Widget buildBottomButton() {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            final animationPercent = Curves.elasticOut
                .transform(buttonInterval.transform(animationController.value));
            final opacity = animationPercent.clamp(0.0, 1.0);
            final scale = (animationPercent * 0.5) + 0.5;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor:
                  mainColor.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            ),
            onPressed: () {},
            child: const Text(
              'Sair',
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: mainColor,
            boxShadow: [
              BoxShadow(
                color: Colors.white60,
                blurStyle: BlurStyle.inner,
                blurRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(.3),
                  Colors.white.withOpacity(.3),
                ],
              ),
            ),
          ),
        ),
        buildContent(),
      ],
    );
  }
}
