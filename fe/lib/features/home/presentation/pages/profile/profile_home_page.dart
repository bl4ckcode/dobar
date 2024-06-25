import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:flutter/material.dart';

class ProfileHomePage extends StatefulWidget {
  const ProfileHomePage({super.key});

  @override
  State<ProfileHomePage> createState() => _ProfileHomePageState();
}

class _ProfileHomePageState extends State<ProfileHomePage> {
  @override
  Widget build(BuildContext context) {
    return const HorizontalSlidingCards(
      list: [],
    );
  }
}
