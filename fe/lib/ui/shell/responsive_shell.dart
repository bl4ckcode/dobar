import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/screens/home_wireframe.dart';
import 'package:barz/ui/screens/find_wireframe.dart';
import 'package:barz/ui/screens/profile_wireframe.dart';

/// Responsive shell that adapts based on platform:
/// - Mobile: Bottom navigation bar
/// - Web/Tablet: Fixed left side menu
/// 
/// This shell only shows AFTER authentication.
/// Login is handled separately before reaching this shell.
class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({super.key});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _selectedIndex = 0;

  static final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _NavItem(icon: Icons.search_outlined, selectedIcon: Icons.search, label: 'Find'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  static final List<Widget> _pages = [
    const HomeWireframe(),
    const FindWireframe(),
    const ProfileWireframe(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use side menu for web or wide screens (tablet/desktop)
        final bool useWideLayout = kIsWeb || constraints.maxWidth >= 768;

        if (useWideLayout) {
          return _buildWideLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  /// Mobile layout with bottom navigation bar
  Widget _buildMobileLayout() {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: barzYellow,
              unselectedItemColor: textTertiary,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              items: _navItems.map((item) {
                final isSelected = _navItems.indexOf(item) == _selectedIndex;
                return BottomNavigationBarItem(
                  icon: Icon(isSelected ? item.selectedIcon : item.icon),
                  label: item.label,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide layout with fixed left side menu (web/tablet/desktop)
  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Fixed side menu
          _buildSideMenu(),
          // Main content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed left side menu for web/tablet
  Widget _buildSideMenu() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: sideMenuBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Brand header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: barzYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_bar, color: barzBlack, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  'dobar',
                  style: TextStyle(
                    color: barzYellow,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: sideMenuDivider, height: 1),
          
          const SizedBox(height: 16),
          
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = index == _selectedIndex;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _onItemTapped(index),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? barzYellow.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected 
                              ? Border.all(color: barzYellow.withValues(alpha: 0.3), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected ? barzYellow : sideMenuUnselectedItem,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? barzYellow : sideMenuUnselectedItem,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const Divider(color: sideMenuDivider, height: 1),
          
          // Bottom section (settings, logout, etc.)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SideMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    // Navigate to settings
                  },
                ),
                const SizedBox(height: 8),
                _SideMenuItem(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () {
                    // Navigate to help
                  },
                ),
                const SizedBox(height: 8),
                _SideMenuItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  onTap: () {
                    // Handle logout
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? errorColor : sideMenuUnselectedItem;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
