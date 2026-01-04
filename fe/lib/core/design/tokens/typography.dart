import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Barz Typography System
/// 
/// Based on Material Design 3 type scale with Inter font family.
/// Inter is chosen for:
/// - Excellent legibility at small sizes
/// - Wide language support
/// - Open source and free
/// - Optimized for screens
/// 
/// Scale follows a 1.25 ratio (major third) for harmonious sizing.

// =============================================================================
// FONT FAMILY
// =============================================================================

/// Primary font family for the app
TextStyle get barzFontFamily => GoogleFonts.inter();

/// Display font for headings (optional: use a display font for branding)
TextStyle get barzDisplayFamily => GoogleFonts.inter();

// =============================================================================
// TYPE SCALE
// =============================================================================

/// Complete text theme for Barz
TextTheme get barzTextTheme => TextTheme(
  // Display styles - Hero text, large headings
  displayLarge: GoogleFonts.inter(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  ),
  displayMedium: GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  ),
  displaySmall: GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  ),
  
  // Headline styles - Page titles, section headers
  headlineLarge: GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  ),
  headlineMedium: GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  ),
  headlineSmall: GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  ),
  
  // Title styles - Card titles, list items
  titleLarge: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  ),
  titleMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  ),
  titleSmall: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  ),
  
  // Body styles - Main content
  bodyLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  ),
  bodyMedium: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  ),
  bodySmall: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  ),
  
  // Label styles - Buttons, form labels, captions
  labelLarge: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  ),
  labelMedium: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
  ),
  labelSmall: GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.45,
  ),
);

// =============================================================================
// FONT WEIGHTS
// =============================================================================

/// Semantic font weights
abstract final class BarzFontWeight {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}
