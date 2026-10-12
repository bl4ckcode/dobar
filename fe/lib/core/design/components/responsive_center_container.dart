import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// A responsive container that centers content on web with appropriate width constraints
///
/// This widget automatically:
/// - Centers content horizontally on web platforms
/// - Applies width constraints (30-50% of screen width on large screens)
/// - Maintains full width on mobile devices
/// - Provides consistent padding across different screen sizes
class ResponsiveCenterContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  /// Maximum width percentage for web (0.1 to 0.95)
  final double maxWidthPercentage;

  /// Minimum width in pixels to prevent content from being too narrow
  final double minWidth;

  /// Maximum width in pixels (absolute cap)
  final double? maxWidth;

  /// Whether to apply responsive layout (defaults to true on web only)
  final bool? applyResponsiveLayout;

  const ResponsiveCenterContainer({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.maxWidthPercentage = 0.4, // Default 40% of screen width
    this.minWidth = 320,
    this.maxWidth = 600,
    this.applyResponsiveLayout,
  }) : assert(
         maxWidthPercentage >= 0.1 && maxWidthPercentage <= 0.95,
         'maxWidthPercentage must be between 0.1 and 0.95',
       );

  @override
  Widget build(BuildContext context) {
    final bool shouldApplyResponsive = applyResponsiveLayout ?? kIsWeb;

    // On mobile or when disabled, just return the child with padding
    if (!shouldApplyResponsive) {
      return Container(color: backgroundColor, padding: padding, child: child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Calculate responsive width
        double effectiveWidth;

        if (screenWidth <= 600) {
          // Mobile: use full width
          effectiveWidth = screenWidth;
        } else if (screenWidth <= 1200) {
          // Tablet: use 60% width
          effectiveWidth = screenWidth * 0.6;
        } else {
          // Desktop: use configured percentage (default 40%)
          effectiveWidth = screenWidth * maxWidthPercentage;
        }

        // Apply constraints
        effectiveWidth = effectiveWidth.clamp(
          minWidth,
          maxWidth ?? double.infinity,
        );

        return Center(
          child: Container(
            width: effectiveWidth,
            color: backgroundColor,
            padding: padding,
            child: child,
          ),
        );
      },
    );
  }
}

/// A scaffold wrapper that provides responsive layout for web
///
/// Use this instead of regular Scaffold for pages that need centered content on web
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;

  /// Whether to wrap the body in ResponsiveCenterContainer
  final bool centerBody;

  /// Custom max width percentage (0.1-0.95)
  final double maxWidthPercentage;

  /// Custom padding for the centered body
  final EdgeInsetsGeometry? bodyPadding;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.centerBody = true,
    this.maxWidthPercentage = 0.4,
    this.bodyPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? barzGoldSoft,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: centerBody
          ? ResponsiveCenterContainer(
              maxWidthPercentage: maxWidthPercentage,
              padding: bodyPadding,
              backgroundColor: backgroundColor,
              child: body,
            )
          : body,
    );
  }
}

/// Extension to easily get responsive breakpoints
extension ResponsiveContext on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= 600 &&
      MediaQuery.of(this).size.width < 1200;
  bool get isDesktop => MediaQuery.of(this).size.width >= 1200;
  bool get isWeb => kIsWeb;

  /// Returns the appropriate max width percentage based on screen size
  double get responsiveMaxWidth {
    if (isMobile) return 1.0;
    if (isTablet) return 0.6;
    return 0.4; // Desktop default
  }
}
