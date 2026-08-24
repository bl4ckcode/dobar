import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/theme/theme_cubit.dart';

class ThemeToggleButton extends StatelessWidget {
  final Color? color;

  const ThemeToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final isDark = context.isDark;

    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      onPressed: () {
        context.read<ThemeCubit>().toggleTheme();
      },
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      icon: Icon(
        isDark ? LucideIcons.sun : LucideIcons.moon,
        size: 20,
        color: color ?? dobar.labelSecondary,
      ),
    );
  }
}
