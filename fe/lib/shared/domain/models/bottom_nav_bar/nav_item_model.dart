import 'package:flutter/material.dart';

/// Simple navigation item model using Material Icons
class NavItemModel {
  final String title;
  final IconData icon;
  final IconData? activeIcon;

  const NavItemModel({
    required this.title,
    required this.icon,
    this.activeIcon,
  });

  IconData get displayIcon => activeIcon ?? icon;
}
