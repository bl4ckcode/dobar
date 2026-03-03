/// Barz Spacing System
///
/// Based on an 8px grid system with golden ratio relationships.
/// This creates visual harmony and consistent rhythm throughout the app.
///
/// The 8px base aligns with:
/// - iOS Human Interface Guidelines (8pt grid)
/// - Material Design (4dp increments, 8dp common)
/// - Web accessibility (scales well at different zoom levels)
library;

// =============================================================================
// BASE SPACING SCALE (8px grid)
// =============================================================================

/// Spacing tokens following a modified modular scale
abstract final class BarzSpacing {
  /// Extra extra small: 2px - hairline gaps
  static const double xxs = 2.0;

  /// Extra small: 4px - tight spacing
  static const double xs = 4.0;

  /// Small: 8px - base unit
  static const double sm = 8.0;

  /// Medium: 12px - comfortable spacing
  static const double md = 12.0;

  /// Large: 16px - standard padding
  static const double lg = 16.0;

  /// Extra large: 24px - section spacing
  static const double xl = 24.0;

  /// Extra extra large: 32px - major sections
  static const double xxl = 32.0;

  /// Triple extra large: 48px - page margins
  static const double xxxl = 48.0;

  /// Huge: 64px - hero sections
  static const double huge = 64.0;
}

// =============================================================================
// COMPONENT-SPECIFIC SPACING
// =============================================================================

/// Spacing for buttons
abstract final class ButtonSpacing {
  static const double paddingHorizontal = 24.0;
  static const double paddingVertical = 14.0;
  static const double paddingCompact = 8.0;
  static const double iconGap = 8.0;
  static const double groupGap = 12.0;
}

/// Spacing for text fields
abstract final class InputSpacing {
  static const double paddingHorizontal = 16.0;
  static const double paddingVertical = 16.0;
  static const double labelGap = 8.0;
  static const double helperGap = 4.0;
  static const double iconPadding = 12.0;
}

/// Spacing for cards
abstract final class CardSpacing {
  static const double padding = 16.0;
  static const double paddingLarge = 24.0;
  static const double margin = 16.0;
  static const double gap = 12.0;
}

/// Spacing for page layouts
abstract final class PageSpacing {
  static const double horizontalPadding = 24.0;
  static const double verticalPadding = 24.0;
  static const double sectionGap = 32.0;
  static const double headerGap = 16.0;
}

// =============================================================================
// TOUCH TARGETS
// =============================================================================

/// Minimum touch target sizes per platform guidelines
abstract final class TouchTargets {
  /// Minimum touch target (WCAG 2.5.5, iOS HIG)
  static const double minimum = 44.0;

  /// Comfortable touch target
  static const double comfortable = 48.0;

  /// Large touch target (accessibility)
  static const double large = 56.0;
}
