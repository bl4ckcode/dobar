import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import '../business_shell.dart';

/// Side navigation menu for web/tablet layout of BusinessShell.
/// 
/// Features:
/// - Bar selector at top (with multi-bar support)
/// - Navigation items with icons and labels
/// - Selected state highlighting
/// - Switch to client mode button at bottom
class BusinessSideMenu extends StatelessWidget {
  final List<BarAccess> bars;
  final BarAccess activeBar;
  final List<BusinessNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavItemSelected;
  final ValueChanged<int> onBarSelected;
  final VoidCallback onSwitchToClientMode;

  const BusinessSideMenu({
    super.key,
    required this.bars,
    required this.activeBar,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavItemSelected,
    required this.onBarSelected,
    required this.onSwitchToClientMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: barzBlack,
      child: Column(
        children: [
          // App branding
          _buildBranding(),
          const Divider(color: Colors.white12, height: 1),
          // Bar selector
          _buildBarSelector(context),
          const Divider(color: Colors.white12, height: 1),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (int i = 0; i < navItems.length; i++)
                  _buildNavItem(navItems[i], i),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Switch to client mode
          _buildSwitchToClientButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: barzYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_bar,
              color: barzBlack,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Dobar Business',
            style: barzTextTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarSelector(BuildContext context) {
    return InkWell(
      onTap: bars.length > 1 ? () => _showBarSelectorMenu(context) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bar avatar/icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: barzYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.store,
                color: barzYellow,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeBar.barName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeBar.role.displayName,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (bars.length > 1)
              Icon(
                Icons.unfold_more,
                color: Colors.grey[400],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showBarSelectorMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        button.localToGlobal(Offset.zero) & button.size,
        Offset.zero & overlay.size,
      ),
      items: bars.map((bar) {
        final isActive = bar.barId == activeBar.barId;
        return PopupMenuItem<int>(
          value: bar.barId,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isActive ? barzYellow : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bar.barName),
                    Text(
                      bar.role.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((barId) {
      if (barId != null && barId != activeBar.barId) {
        onBarSelected(barId);
      }
    });
  }

  Widget _buildNavItem(BusinessNavItem item, int index) {
    final isSelected = index == selectedIndex;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? barzYellow.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onNavItemSelected(index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? barzYellow : Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? barzYellow : Colors.grey[300],
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: barzYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchToClientButton() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onSwitchToClientMode,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Client Mode',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
