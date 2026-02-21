import 'package:flutter/material.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : surfaceWhite;
    final borderColor = isDark ? barzDarkMuted : surfaceDim;

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
                      ? Icons.keyboard_double_arrow_left
                      : Icons.keyboard_double_arrow_right,
                  label: 'Collapse',
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  isGold: false,
                ),
                const SizedBox(height: 4),
                _buildSidebarButton(
                  isDark: isDark,
                  icon: Icons.logout,
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
    return InkWell(
      onTap: widget.bars.length > 1
          ? () => _showBarSelectorMenu(context, isDark)
          : null,
      hoverColor: isDark ? Colors.white12 : Colors.black12,
      child: Container(
        height: 64, // h-16 in Tailwind
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 22),
            // Icon box
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: barzGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wine_bar, color: barzDark, size: 20),
            ),
            // The expanding/fading part
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activeBar.barName,
                            style: TextStyle(
                              color: isDark ? textOnDark : textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                          Text(
                            widget.activeBar.role.displayName,
                            style: TextStyle(
                              color: isDark ? textTertiary : textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                    if (widget.bars.length > 1)
                      Icon(
                        Icons.unfold_more,
                        color: isDark ? textTertiary : textSecondary,
                        size: 16,
                      ),
                    const SizedBox(width: 16),
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

    final bgColor = isDark ? barzDarkLight : surfaceWhite;
    final textColor = isDark ? textOnDark : textPrimary;
    final secTextColor = isDark ? textTertiary : textSecondary;

    final menuItems = <PopupMenuEntry<int>>[
      ...widget.bars.map((bar) {
        final isActive = bar.barId == widget.activeBar.barId;
        return PopupMenuItem<int>(
          value: bar.barId,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isActive ? barzGold : secTextColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bar.barName, style: TextStyle(color: textColor)),
                    Text(
                      bar.role.displayName,
                      style: TextStyle(fontSize: 12, color: secTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
      const PopupMenuDivider(),
      PopupMenuItem<int>(
        value: -1,
        child: Row(
          children: [
            const Icon(Icons.add_business_rounded, color: barzGold, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Add Bar',
              style: TextStyle(color: barzGold, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ];

    showMenu<int>(
      context: context,
      color: bgColor,
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
    final hoverBg = isDark ? Colors.white12 : Colors.black12;
    final iconColor = isGold
        ? barzGold
        : (isDark ? textTertiary : textSecondary);
    final textColor = isGold
        ? barzGold
        : (isDark ? const Color(0xFFB0B0B0) : textSecondary);

    return Material(
      color: backgroundColor ?? Colors.transparent,
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
