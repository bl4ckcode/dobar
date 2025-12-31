import 'package:flutter/material.dart';
import 'colors.dart';

class BarzTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: barzBlack,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: barzBlack,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: barzBlack,
  );
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: barzYellow,
  );
}

class BarzSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}