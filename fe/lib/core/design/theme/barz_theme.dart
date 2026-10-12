import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';

/// Barz Theme Configuration
///
/// Complete theme setup for the Barz app following Material Design 3.
/// Provides both light and dark themes with consistent styling.

/// Get the light theme for Barz
ThemeData getBarzLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: barzLightColorScheme,
    textTheme: barzTextTheme,
    scaffoldBackgroundColor: barzGoldSoft, // Warmer/softer white for light mode
    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: barzGoldSoft,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: barzTextTheme.titleLarge?.copyWith(color: textPrimary),
      iconTheme: const IconThemeData(color: textPrimary),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceWhite,
      selectedItemColor:
          barzGoldDark, // Darker gold for better contrast on white
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Navigation Bar (M3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceWhite,
      indicatorColor: barzGold.withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 2,
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: barzGold,
      foregroundColor: barzDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(BarzRadii.lg)),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: surfaceWhite,
      elevation: 2,
      shadowColor: barzDark.withValues(alpha: 0.05), // Lighter shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      margin: EdgeInsets.zero,
    ),

    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return barzGold.withValues(alpha: stateDisabledOpacity);
          }
          return barzGold;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return barzDark.withValues(alpha: stateDisabledOpacity);
          }
          return barzDark;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(0, TouchTargets.minimum),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: ButtonSpacing.paddingHorizontal,
            vertical: ButtonSpacing.paddingVertical,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(barzTextTheme.labelLarge),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return barzDark.withValues(alpha: stateDisabledOpacity);
          }
          return barzDark;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(0, TouchTargets.minimum),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: ButtonSpacing.paddingHorizontal,
            vertical: ButtonSpacing.paddingVertical,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(
              color: barzDark.withValues(alpha: stateDisabledOpacity),
              width: 2,
            );
          }
          return const BorderSide(color: barzDark, width: 2);
        }),
        textStyle: WidgetStateProperty.all(barzTextTheme.labelLarge),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return barzDark.withValues(alpha: stateDisabledOpacity);
          }
          return barzDark;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(0, TouchTargets.minimum),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: ButtonSpacing.paddingHorizontal,
            vertical: ButtonSpacing.paddingVertical,
          ),
        ),
        textStyle: WidgetStateProperty.all(barzTextTheme.labelLarge),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: barzGoldMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: InputSpacing.paddingHorizontal,
        vertical: InputSpacing.paddingVertical,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzDark, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      hintStyle: barzTextTheme.bodyLarge?.copyWith(color: textTertiary),
      labelStyle: barzTextTheme.bodyLarge?.copyWith(color: textSecondary),
      errorStyle: barzTextTheme.bodySmall?.copyWith(color: errorRed),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceWhite,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.lg),
      ),
      titleTextStyle: barzTextTheme.headlineSmall?.copyWith(color: textPrimary),
      contentTextStyle: barzTextTheme.bodyMedium?.copyWith(
        color: textSecondary,
      ),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceWhite,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BarzRadii.lg)),
      ),
      showDragHandle: true,
      dragHandleColor: surfaceDim,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: barzDark,
      contentTextStyle: barzTextTheme.bodyMedium?.copyWith(color: textOnDark),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.sm),
      ),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: surfaceDim,
      thickness: 1,
      space: BarzSpacing.lg,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMuted,
      selectedColor: barzGold.withValues(alpha: 0.2),
      labelStyle: barzTextTheme.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return barzGold;
        }
        return surfaceMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return barzGold.withValues(alpha: 0.5);
        }
        return surfaceDim;
      }),
    ),

    // Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return barzGold;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(barzDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.xs),
      ),
      side: const BorderSide(color: barzDark, width: 2),
    ),

    // Radio
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return barzGold;
        }
        return textSecondary;
      }),
    ),

    // Progress Indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: barzGold,
      linearTrackColor: surfaceDim,
      circularTrackColor: surfaceDim,
    ),

    // Tab Bar
    tabBarTheme: TabBarThemeData(
      labelColor: barzDark,
      unselectedLabelColor: textSecondary,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: barzGold, width: 3),
      ),
      labelStyle: barzTextTheme.labelLarge,
      unselectedLabelStyle: barzTextTheme.labelLarge,
    ),

    // List Tile
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BarzSpacing.lg,
        vertical: BarzSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
      ),
      tileColor: Colors.transparent,
      selectedTileColor: barzGold.withValues(alpha: 0.1),
    ),
    extensions: [dobarLightColors],
  );
}

/// Get the dark theme for Barz
ThemeData getBarzDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: barzDarkColorScheme,
    textTheme: barzTextTheme.apply(
      bodyColor: textOnDark,
      displayColor: textOnDark,
    ),
    scaffoldBackgroundColor: barzDark, // Deep Onyx
    // App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: barzDark,
      foregroundColor: textOnDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
    ),

    // Bottom Nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: barzDarkLight, // Slightly lighter for contrast
      selectedItemColor: barzGold,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0, // Flat in dark mode usually looks better
    ),

    // Cards - Dark Mode
    cardTheme: CardThemeData(
      color: barzDarkLight, // Matte surface
      elevation: 0, // Flat style for industrial vibe
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        side: const BorderSide(color: barzDarkMuted, width: 1), // Thin border
      ),
      margin: EdgeInsets.zero,
    ),

    // Input Decoration - Dark Mode
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: barzDarkLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: InputSpacing.paddingHorizontal,
        vertical: InputSpacing.paddingVertical,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzDarkMuted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzDarkMuted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzGold, width: 1),
      ),
    ),
    extensions: [dobarDarkColors],
  );
}
