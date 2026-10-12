import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';

class BarzToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const BarzToolbar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.centerTitle = false,
    this.bottom,
  });

  factory BarzToolbar.simple({
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
  }) {
    return BarzToolbar(
      title: title,
      actions: actions,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
    );
  }

  factory BarzToolbar.business({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    PreferredSizeWidget? bottom,
  }) {
    return BarzToolbar(
      title: title,
      actions: actions,
      leading: leading,
      showBackButton: false,
      backgroundColor: barzDark,
      foregroundColor: Colors.white,
      bottom: bottom,
    );
  }

  factory BarzToolbar.transparent({
    String? title,
    Widget? titleWidget,
    List<Widget>? actions,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
  }) {
    return BarzToolbar(
      title: title,
      titleWidget: titleWidget,
      actions: actions,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  factory BarzToolbar.gold({
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
  }) {
    return BarzToolbar(
      title: title,
      actions: actions,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      backgroundColor: barzGold,
      foregroundColor: barzDark,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      title:
          titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: foregroundColor ?? theme.appBarTheme.foregroundColor,
                  ),
                )
              : null),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? barzGoldSoft,
      foregroundColor: foregroundColor ?? textPrimary,
      elevation: elevation,
      scrolledUnderElevation: elevation,
      leading:
          leading ??
          (showBackButton && canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                )
              : null),
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      bottom: bottom,
    );
  }
}
