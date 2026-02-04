import 'package:flutter/material.dart';
import 'dobar_colors.dart';

/// Barz Color System
///
/// Based on perceptual color science and accessibility standards:
/// - Primary yellow chosen for warmth and energy (hospitality industry)
/// - Contrast ratios meet WCAG AA standards (4.5:1 for normal text)
/// - Opacity levels follow Material Design 3 state layers
///
/// Color Psychology:
/// - Yellow/Gold: Energy, optimism, warmth, appetite stimulation
/// - Black/Dark: Sophistication, elegance, premium feel
/// - Cream/Off-white: Comfort, approachability, cleanliness

// =============================================================================
// BRAND COLORS - Core identity
// =============================================================================

/// Primary brand gold - dobar identity yellow
/// HSL: 50°, 100%, 68% - warm golden yellow from logo
const Color barzGold = Color(0xFFFFDE59); // Dobar Yellow

/// Softer gold variants for backgrounds and subtle elements
const Color barzGoldLight = Color(0xFFFFEB85); // Lighter variant (10% lighter)
const Color barzGoldSoft = Color(
  0xFFFFFDE7,
); // Very pale yellow - main backgrounds (Light Mode)
const Color barzGoldMuted = Color(
  0xFFFFF8E1,
); // Muted yellow - input backgrounds
const Color barzGoldDark = Color(
  0xFFE5C74F,
); // Darker for accents/pressed states (10% darker)

/// Primary dark color - sophisticated near-black
const Color barzDark = Color(0xFF0A0A0A); // Deep Onyx Black

/// Dark variants
const Color barzDarkLight = Color(
  0xFF121212,
); // Elevated surfaces in dark mode (Matte)
const Color barzDarkMuted = Color(0xFF2C2C2C); // Secondary text, icons, borders

// =============================================================================
// SEMANTIC COLORS - Meaning-driven
// =============================================================================

const Color successGreen = Color(0xFF28A745);
const Color successGreenLight = Color(0xFFD4EDDA);
const Color warningOrange = Color(0xFFFF9800);
const Color warningOrangeLight = Color(0xFFFFF3E0);
const Color errorRed = Color(0xFFDC3545);
const Color errorRedLight = Color(0xFFF8D7DA);
const Color infoBlue = Color(0xFF17A2B8);
const Color infoBlueLight = Color(0xFFD1ECF1);

// =============================================================================
// SURFACE COLORS - UI layers
// =============================================================================

const Color surfaceWhite = Color(0xFFFFFFFF);
const Color surfaceLight = Color(0xFFFAFAFA); // Slightly off-white
const Color surfaceMuted = Color(0xFFF5F5F5); // Cards, elevated surfaces
const Color surfaceDim = Color(0xFFEEEEEE); // Dividers, borders
const Color surfacePrimary = Color(
  0xFFFFFBF5,
); // Main scaffold - subtle warm off-white

// =============================================================================
// TEXT COLORS - Readable at all sizes
// =============================================================================

const Color textPrimary = Color(0xFF1A1A2E); // Main body text
const Color textSecondary = Color(0xFF6B6B7B); // Secondary, captions
const Color textTertiary = Color(0xFF9E9E9E); // Hints, placeholders
const Color textOnDark = Color(0xFFFFFFFF); // Text on dark backgrounds
const Color textOnGold = Color(0xFF1A1A2E); // Text on gold backgrounds

// =============================================================================
// STATE COLORS - Interaction feedback
// =============================================================================

/// Opacity levels for state overlays (Material Design 3 spec)
const double stateHoverOpacity = 0.08;
const double stateFocusOpacity = 0.12;
const double statePressedOpacity = 0.16;
const double stateDisabledOpacity = 0.38;
const double stateDragOpacity = 0.16;

// =============================================================================
// LEGACY ALIASES - For backwards compatibility
// =============================================================================

@Deprecated('Use barzGold instead')
const Color barzYellow = barzGold;

@Deprecated('Use barzDark instead')
const Color barzBlack = barzDark;

@Deprecated('Use barzGoldSoft instead')
const Color barzCream = barzGoldSoft;

// =============================================================================
// COLOR SCHEME EXTENSION
// =============================================================================

/// Extension to add Barz-specific semantic colors to ColorScheme
extension BarzColors on ColorScheme {
  /// Soft primary color for backgrounds (7% opacity)
  Color get primarySoft => primary.withValues(alpha: 0.07);

  /// Muted primary for subtle highlights (15% opacity)
  Color get primaryMuted => primary.withValues(alpha: 0.15);

  /// Surface for inputs/text fields
  Color get inputSurface =>
      brightness == Brightness.light ? barzGoldMuted : barzDarkLight;

  /// Border color for inputs
  Color get inputBorder => brightness == Brightness.light
      ? barzDark.withValues(alpha: 0.2)
      : surfaceDim;
}

// =============================================================================
// COLOR SCHEME DEFINITIONS
// =============================================================================

/// Light theme color scheme
const ColorScheme barzLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: barzGold,
  onPrimary: barzDark,
  primaryContainer: barzGoldLight,
  onPrimaryContainer: barzDark,
  secondary: barzDark,
  onSecondary: surfaceWhite,
  secondaryContainer: barzDarkLight,
  onSecondaryContainer: surfaceWhite,
  tertiary: warningOrange,
  onTertiary: surfaceWhite,
  tertiaryContainer: warningOrangeLight,
  onTertiaryContainer: barzDark,
  error: errorRed,
  onError: surfaceWhite,
  errorContainer: errorRedLight,
  onErrorContainer: errorRed,
  surface: surfaceWhite,
  onSurface: textPrimary,
  surfaceContainerHighest: surfaceMuted,
  onSurfaceVariant: textSecondary,
  outline: surfaceDim,
  outlineVariant: Color(0xFFE0E0E0),
  shadow: Color(0x1A000000),
  scrim: Color(0x99000000),
  inverseSurface: barzDark,
  onInverseSurface: surfaceWhite,
  inversePrimary: barzGoldLight,
);

/// Dark theme color scheme
const ColorScheme barzDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: barzGoldLight,
  onPrimary: barzDark,
  primaryContainer: barzGoldDark,
  onPrimaryContainer: barzGoldSoft,
  secondary: barzGoldLight,
  onSecondary: barzDark,
  secondaryContainer: barzDarkLight,
  onSecondaryContainer: surfaceWhite,
  tertiary: warningOrange,
  onTertiary: barzDark,
  tertiaryContainer: Color(0xFF5D4037),
  onTertiaryContainer: warningOrangeLight,
  error: Color(0xFFCF6679),
  onError: barzDark,
  errorContainer: Color(0xFF93000A),
  onErrorContainer: errorRedLight,
  surface: barzDark,
  onSurface: surfaceWhite,
  surfaceContainerHighest: barzDarkLight,
  onSurfaceVariant: Color(0xFFB0B0B0),
  outline: barzDarkMuted,
  outlineVariant: Color(0xFF3D3D3D),
  shadow: Color(0x40000000),
  scrim: Color(0xCC000000),
  inverseSurface: surfaceWhite,
  onInverseSurface: barzDark,
  inversePrimary: barzGold,
);

const dobarLightColors = DobarColors(
  labelPrimary: barzDark,
  labelSecondary: textSecondary,
  labelSelected: barzGold,
  labelOnSelected: barzDark,
  background: barzGoldSoft,
  surface: surfaceWhite,
  surfaceElevated: surfaceMuted,
  navBackground: barzDark,
  navIcon: Color(0xFFB0B0B0),
  navIconSelected: barzGold,
  navLabel: textOnDark,
  buttonPrimary: barzGold,
  buttonOnPrimary: barzDark,
);

const dobarDarkColors = DobarColors(
  labelPrimary: textOnDark,
  labelSecondary: Color(0xFFB0B0B0),
  labelSelected: barzGold,
  labelOnSelected: textOnDark,
  background: barzDark,
  surface: barzDarkLight,
  surfaceElevated: barzDarkMuted,
  navBackground: barzDark,
  navIcon: Color(0xFFB0B0B0),
  navIconSelected: barzGold,
  navLabel: textOnDark,
  buttonPrimary: barzGold,
  buttonOnPrimary: barzDark,
);
