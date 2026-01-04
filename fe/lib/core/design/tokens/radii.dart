/// Barz Border Radius System
/// 
/// Consistent corner radii create visual unity across the app.
/// Uses a geometric progression for harmonious scaling.
library;

// =============================================================================
// BORDER RADIUS TOKENS
// =============================================================================

abstract final class BarzRadii {
  /// None: 0px - Sharp corners
  static const double none = 0.0;
  
  /// Extra small: 4px - Subtle rounding
  static const double xs = 4.0;
  
  /// Small: 8px - Buttons, chips
  static const double sm = 8.0;
  
  /// Medium: 12px - Cards, inputs
  static const double md = 12.0;
  
  /// Large: 16px - Modals, sheets
  static const double lg = 16.0;
  
  /// Extra large: 24px - FABs, large cards
  static const double xl = 24.0;
  
  /// Full/Pill: 999px - Fully rounded (pills)
  static const double full = 999.0;
}

// =============================================================================
// ELEVATION / SHADOWS
// =============================================================================

abstract final class BarzElevation {
  /// Level 0: No shadow
  static const double none = 0.0;
  
  /// Level 1: Subtle lift (cards)
  static const double sm = 2.0;
  
  /// Level 2: Standard elevation (FABs)
  static const double md = 4.0;
  
  /// Level 3: Higher elevation (menus)
  static const double lg = 8.0;
  
  /// Level 4: Highest (dialogs)
  static const double xl = 16.0;
}
