import 'package:flutter/material.dart';

class DobarColors extends ThemeExtension<DobarColors> {
  final Color labelPrimary;
  final Color labelSecondary;
  final Color labelSelected;
  final Color labelOnSelected;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color navBackground;
  final Color navIcon;
  final Color navIconSelected;
  final Color navLabel;
  final Color buttonPrimary;
  final Color buttonOnPrimary;

  const DobarColors({
    required this.labelPrimary,
    required this.labelSecondary,
    required this.labelSelected,
    required this.labelOnSelected,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.navBackground,
    required this.navIcon,
    required this.navIconSelected,
    required this.navLabel,
    required this.buttonPrimary,
    required this.buttonOnPrimary,
  });

  @override
  DobarColors copyWith({
    Color? labelPrimary,
    Color? labelSecondary,
    Color? labelSelected,
    Color? labelOnSelected,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? navBackground,
    Color? navIcon,
    Color? navIconSelected,
    Color? navLabel,
    Color? buttonPrimary,
    Color? buttonOnPrimary,
  }) {
    return DobarColors(
      labelPrimary: labelPrimary ?? this.labelPrimary,
      labelSecondary: labelSecondary ?? this.labelSecondary,
      labelSelected: labelSelected ?? this.labelSelected,
      labelOnSelected: labelOnSelected ?? this.labelOnSelected,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      navBackground: navBackground ?? this.navBackground,
      navIcon: navIcon ?? this.navIcon,
      navIconSelected: navIconSelected ?? this.navIconSelected,
      navLabel: navLabel ?? this.navLabel,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonOnPrimary: buttonOnPrimary ?? this.buttonOnPrimary,
    );
  }

  @override
  DobarColors lerp(ThemeExtension<DobarColors>? other, double t) {
    if (other is! DobarColors) return this;
    return DobarColors(
      labelPrimary: Color.lerp(labelPrimary, other.labelPrimary, t)!,
      labelSecondary: Color.lerp(labelSecondary, other.labelSecondary, t)!,
      labelSelected: Color.lerp(labelSelected, other.labelSelected, t)!,
      labelOnSelected: Color.lerp(labelOnSelected, other.labelOnSelected, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navIcon: Color.lerp(navIcon, other.navIcon, t)!,
      navIconSelected: Color.lerp(navIconSelected, other.navIconSelected, t)!,
      navLabel: Color.lerp(navLabel, other.navLabel, t)!,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t)!,
      buttonOnPrimary: Color.lerp(buttonOnPrimary, other.buttonOnPrimary, t)!,
    );
  }
}

extension DobarColorsContext on BuildContext {
  DobarColors get dobarColors => Theme.of(this).extension<DobarColors>()!;
}
