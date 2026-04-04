import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import '../business_shell.dart';

/// Side navigation menu for web/tablet layout of BusinessShell.
class BusinessSideMenu extends StatefulWidget {
  final List<BarAccess> bars;
  final BarAccess activeBar;
  final List<BusinessNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavItemSelected;
  final ValueChanged<int> onBarSelected;

  const BusinessSideMenu({
    super.key,
    required this.bars,
    required this.activeBar,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavItemSelected,
    required this.onBarSelected,
  });

  @override
  State<BusinessSideMenu> createState() => _BusinessSideMenuState();
}

class _BusinessSideMenuState extends State<BusinessSideMenu> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : surfaceWhite;
    final borderColor = isDark ? const Color(0xFF1A1A1A) : surfaceDim;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isExpanded ? 260 : 80,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Bar Selector Header
          _buildBarSelectorHeader(context, isDark, borderColor),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              children: [
                for (int i = 0; i < widget.navItems.length; i++)
                  _buildNavItem(widget.navItems[i], i, isDark),
              ],
            ),
          ),

          // Bottom area: Logout and Expand
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                _buildSidebarButton(
                  isDark: isDark,
                  icon: _isExpanded
                      ? LucideIcons.chevronsLeft
                      : LucideIcons.chevronsRight,
                  label: 'Collapse',
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  isGold: false,
                ),
                const SizedBox(height: 4),
                _buildSidebarButton(
                  isDark: isDark,
                  icon: LucideIcons.logOut,
                  label: 'Logout',
                  onTap: () => context.read<SessionBloc>().add(
                    const SessionEvent.logout(),
                  ),
                  isGold: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarSelectorHeader(
    BuildContext context,
    bool isDark,
    Color borderColor,
  ) {
    const bgColor = Color(0xFF0A0A0A);
    const cardColor = Color(0xFF121212);
    const goldColor = Color(0xFFFFDE59);

    return InkWell(
      onTap: widget.bars.length > 1
          ? () => _showBarSelectorMenu(context, isDark)
          : null,
      hoverColor: Colors.white.withValues(alpha: 0.05),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            // Premium Icon Box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: goldColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.store, color: goldColor, size: 22),
            ),
            // Information Section
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activeBar.barName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              fontFamily: 'SF Pro Display',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: goldColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              widget.activeBar.role.displayName.toUpperCase(),
                              style: const TextStyle(
                                color: goldColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.bars.length > 1)
                      const Icon(
                        LucideIcons.chevronsUpDown,
                        color: Colors.white38,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarSelectorMenu(BuildContext context, bool isDark) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    const bgColor = Color(0xFF121212);
    const goldColor = Color(0xFFFFDE59);

    final menuItems = <PopupMenuEntry<int>>[
      const PopupMenuSectionHeader(label: 'SWITCH BUSINESS'),
      ...widget.bars.map((bar) {
        final isActive = bar.barId == widget.activeBar.barId;
        return PopupMenuItem<int>(
          value: bar.barId,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? goldColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? goldColor : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.store,
                    color: isActive ? Colors.black : Colors.white70,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bar.barName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bar.role.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? goldColor : Colors.white38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(LucideIcons.check, color: goldColor, size: 16),
              ],
            ),
          ),
        );
      }),
      const PopupMenuDivider(height: 1),
      PopupMenuItem<int>(
        value: -1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(LucideIcons.plus, color: goldColor, size: 16),
              ),
              const SizedBox(width: 12),
              const Text(
                'ADD NEW BUSINESS',
                style: TextStyle(
                  color: goldColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    showMenu<int>(
      context: context,
      color: bgColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      position: RelativeRect.fromRect(
        button.localToGlobal(Offset.zero) & button.size,
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    ).then((value) {
      if (value == null) return;
      if (value == -1) {
        if (context.mounted) {
          _navigateToCreateBar(context);
        }
      } else if (value != widget.activeBar.barId) {
        widget.onBarSelected(value);
      }
    });
  }

  Future<void> _navigateToCreateBar(BuildContext context) async {
    final result = await context.push<bool>('/create-bar');
    if (result == true && context.mounted) {
      context.read<SessionBloc>().add(const SessionEvent.refreshBarAccess());
    }
  }

  Widget _buildSidebarButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isGold,
    Color? backgroundColor,
  }) {
    final iconColor = isGold
        ? barzGold
        : (isDark ? Colors.white.withValues(alpha: 0.5) : textSecondary);
    final textColor = isGold
        ? barzGold
        : (isDark ? Colors.white.withValues(alpha: 0.7) : textSecondary);
    final selectedBg = isDark
        ? barzGold.withValues(alpha: 0.08)
        : barzGold.withValues(alpha: 0.1);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Material(
      color: isGold ? selectedBg : (backgroundColor ?? Colors.transparent),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverBg,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isExpanded ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BusinessNavItem item, int index, bool isDark) {
    final isSelected = index == widget.selectedIndex;
    final selectedBg = barzGold.withValues(alpha: 0.1);

    return _buildSidebarButton(
      isDark: isDark,
      icon: item.icon,
      label: item.label,
      onTap: () => widget.onNavItemSelected(index),
      isGold: isSelected,
      backgroundColor: isSelected ? selectedBg : null,
    );
  }
}

class PopupMenuSectionHeader extends PopupMenuEntry<Never> {
  final String label;
  const PopupMenuSectionHeader({super.key, required this.label});

  @override
  double get height => 40;

  @override
  bool represents(Never? value) => false;

  @override
  State<PopupMenuSectionHeader> createState() => _PopupMenuSectionHeaderState();
}

class _PopupMenuSectionHeaderState extends State<PopupMenuSectionHeader> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        widget.label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
