import 'package:flutter/material.dart';
import '../primitives/barz_app_bar.dart';
import '../primitives/barz_card.dart';
import '../../core/utils/constant/styles.dart';
import '../../core/utils/constant/colors.dart';

class ProfileWireframe extends StatelessWidget {
  const ProfileWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Profile'),
      backgroundColor: barzYellow,
      body: ListView(
        padding: const EdgeInsets.all(BarzSpacing.lg),
        children: [
          BarzCard(child: Text('Profile Picture, Name, Email/Phone', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Past Activities', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Cashback/Rewards', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Settings', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Help/Support', style: BarzTextStyles.subtitle)),
          BarzCard(child: Text('Logout Button', style: BarzTextStyles.subtitle)),
        ],
      ),
    );
  }
}