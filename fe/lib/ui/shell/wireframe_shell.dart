import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import '../screens/home_connected.dart';
import '../screens/find_connected.dart';
import '../screens/profile_wireframe.dart';

/// Bottom navigation constants for consistent sizing across the app
/// 
/// The FAB sits in a circular notch carved out of the BottomAppBar.
/// These values are calculated to ensure the FAB perfectly fills the notch.
class _NavBarMetrics {
  /// Height of the bottom app bar
  static const double barHeight = 56.0;
  
  /// Gap between FAB edge and notch edge (minimal for snug fit)
  static const double notchMargin = 4.0;
  
  /// FAB diameter calculated to fill the notch perfectly
  static const double fabDiameter = 64.0;
  
  /// Total notch width = fabDiameter + (2 * notchMargin) = 72.0
  static const double notchWidth = fabDiameter + (2 * notchMargin);
}

class WireframeShell extends StatefulWidget {
  const WireframeShell({super.key});

  @override
  State<WireframeShell> createState() => _WireframeShellState();
}

class _WireframeShellState extends State<WireframeShell> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const HomeConnected(),
    const FindConnected(),
    const ProfileWireframe(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: _CenterDockedFab(
        onPressed: () => context.push('/checkin'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: _NavBarMetrics.barHeight,
        color: barzDark,
        shape: const CircularNotchedRectangle(),
        notchMargin: _NavBarMetrics.notchMargin,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              isSelected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            _NavItem(
              icon: Icons.search_outlined,
              selectedIcon: Icons.search,
              label: 'Find',
              isSelected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            // Spacer for the FAB notch
            SizedBox(width: _NavBarMetrics.notchWidth),
            _NavItem(
              icon: Icons.shopping_cart_outlined,
              selectedIcon: Icons.shopping_cart,
              label: 'Cart',
              isSelected: false,
              onTap: () => context.push('/cart'),
            ),
            _NavItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
              isSelected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center-docked FAB that perfectly fills the notch
/// 
/// Uses a circular shape with QR code icon and "Check-in" label below.
/// The label is positioned using a Column to keep the FAB circular.
class _CenterDockedFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _CenterDockedFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _NavBarMetrics.fabDiameter,
          height: _NavBarMetrics.fabDiameter,
          child: FloatingActionButton(
            heroTag: 'shell_checkin_fab',
            onPressed: onPressed,
            backgroundColor: barzGold,
            foregroundColor: barzDark,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.qr_code_scanner, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check-in',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: barzDark,
          ),
        ),
      ],
    );
  }
}

/// Individual navigation item with icon and optional label
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? barzGold : Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}