import 'package:flutter/material.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class HomeWireframe extends StatelessWidget {
  const HomeWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Home'),
      backgroundColor: barzYellow,
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          BarzCard(child: Text('Drinks/Cashback Promotions', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Bars/Restaurants Exclusive', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Drinks Section', style: BarzTextStyles.subtitle)),
        ],
      ),
    );
  }
}