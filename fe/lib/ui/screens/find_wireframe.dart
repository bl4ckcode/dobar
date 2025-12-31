import 'package:flutter/material.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class FindWireframe extends StatelessWidget {
  const FindWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Find'),
      backgroundColor: barzYellow,
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          BarzCard(child: Text('Search Bar', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Nearby Bars/Restaurants List', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Map View (Wireframe)', style: BarzTextStyles.subtitle)),
        ],
      ),
    );
  }
}