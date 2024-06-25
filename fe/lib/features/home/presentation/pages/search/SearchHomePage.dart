import 'package:barz/shared/presentation/widget/parallax_scroll_widget/horizontal_sliding_cards.dart';
import 'package:flutter/material.dart';

class SearchHomePage extends StatefulWidget {
  const SearchHomePage({super.key});

  @override
  State<SearchHomePage> createState() => _SearchHomePageState();
}

class _SearchHomePageState extends State<SearchHomePage> {
  @override
  Widget build(BuildContext context) {
    return const HorizontalSlidingCards(
      list: [],
    );
  }
}
