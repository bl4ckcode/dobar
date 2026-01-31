import 'package:barz/core/utils/extensions/hex_color.dart';
import 'package:flutter/material.dart';

/// Barz App Color Palette
/// Designed following Material Design 3 and WCAG 2.1 accessibility guidelines
/// for optimal readability and contrast in a payments application.

// =============================================================================
// BRAND COLORS
// =============================================================================

/// Primary brand yellow - dobar identity yellow
/// Matches the new dobar logo (#FFDE59)
const Color barzYellow = Color(0xFFFFDE59); // Dobar Yellow

/// Primary brand yellow with variations for different states
const Color barzYellowLight = Color(
  0xFFFFEB85,
); // Lighter variant (10% lighter)
const Color barzYellowSoft = Color(
  0xFFFFF3CD,
); // Very soft - for subtle backgrounds
const Color barzYellowDark = Color(
  0xFFE5C74F,
); // Darker shade for accents (10% darker)

/// Main black - Deep Onyx Black for premium feel
const Color barzBlack = Color(0xFF0A0A0A); // Deep Onyx Black

/// Cream background - warm and soft for main app background
const Color barzCream = Color(
  0xFFFFF8E1,
); // Soft cream, same as backgroundYellow

// =============================================================================
// SEMANTIC COLORS
// =============================================================================

const Color successColor = Color(0xFF28A745);
const Color warningColor = Color(0xFFFFC107);
const Color errorColor = Color(0xFFDC3545);
const Color infoColor = Color(0xFF17A2B8);

// =============================================================================
// UI COLORS - Following Material Design 3 patterns
// =============================================================================

const Color mainColor = barzBlack;
const Color accentColor = barzYellow;

/// Surface colors with proper contrast ratios
const Color surfaceLight = Color(0xFFFFFBF5); // Warm white, not harsh
const Color surfaceDim = Color(0xFFF5F0E8); // Slightly dimmed surface
const Color surfaceBright = Color(0xFFFFFFFF);

/// Background colors - soft, easy on the eyes
const Color backgroundColorLight = Color(0xFFFAF8F5); // Warm off-white
const Color backgroundColorDark = Color(0xFF121212); // True dark for OLED
const Color backgroundYellow = Color(0xFFFFF8E1); // Very soft yellow background

/// Shadow colors with proper opacity
const Color shadowColorLight = Color(0x1A4A5367); // 10% opacity
const Color shadowColorDark = Color(0x4D000000); // 30% opacity

/// SMS/OTP input background - soft and readable
const Color backgroundLightSMS = Color(0xFFFFF3CD);

const Color lighterBluer = Color(0xFF8C94A6);

/// Bottom navigation with warm cream tone
final Color bottomNavigationBarColor = HexColor.fromHex('#FFFBF1');

const Color backgroundColor2 = Color(0xFF17203A);

// =============================================================================
// TEXT COLORS - Optimized for readability
// =============================================================================

const Color textPrimary = Color(0xFF1A1A2E);
const Color textSecondary = Color(0xFF5C5C6E);
const Color textTertiary = Color(0xFF8E8E9A);
const Color textOnYellow = Color(
  0xFF1A1A2E,
); // Dark text on yellow for contrast
const Color textOnDark = Color(0xFFFFFBF5); // Off-white text on dark

// =============================================================================
// CARD & CONTAINER COLORS
// =============================================================================

const Color cardBackground = Colors.white;
const Color cardBorder = Color(0xFFE8E4DC);
const Color cardShadow = Color(0x0D000000); // Very subtle shadow

// =============================================================================
// NAVIGATION COLORS
// =============================================================================

const Color navBarBackground = Color(0xFFFFFBF1); // Cream background
const Color navBarSelectedItem = barzYellow;
const Color navBarUnselectedItem = Color(0xFF9E9E9E);

/// Side menu colors for web
const Color sideMenuBackground = Color(0xFF1A1A2E);
const Color sideMenuSelectedItem = barzYellow;
const Color sideMenuUnselectedItem = Color(0xFFB0B0B0);
const Color sideMenuDivider = Color(0xFF2D2D44);

// =============================================================================
// GRADIENT DEFINITIONS
// =============================================================================

/// Soft yellow gradient for backgrounds - reduces harshness
const LinearGradient yellowBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFFF8E1), // Very soft yellow at top
    Color(0xFFFFF3CD), // Slightly warmer at bottom
  ],
);

/// Dark gradient for login/auth screens
const LinearGradient darkBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
);

// =============================================================================
// HELPER METHODS
// =============================================================================

/// Get overlay color with specified opacity
Color overlayColor(double opacity) => Colors.black.withValues(alpha: opacity);

/// Get yellow with opacity for subtle effects
Color yellowWithOpacity(double opacity) =>
    barzYellow.withValues(alpha: opacity);
