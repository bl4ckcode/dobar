import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_connected.dart';
import '../screens/find_connected.dart';
import '../screens/profile_wireframe.dart';
import '../../core/utils/constant/colors.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shell_checkin_fab',
        onPressed: () => context.push('/checkin'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Check-in'),
        backgroundColor: barzYellow,
        foregroundColor: barzBlack,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: barzBlack,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.search, 'Find'),
            const SizedBox(width: 80), // Space for FAB
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              color: Colors.white,
              tooltip: 'Cart',
              onPressed: () => context.push('/cart'),
            ),
            _buildNavItem(2, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? barzYellow : Colors.white,
      tooltip: label,
      onPressed: () => _onItemTapped(index),
    );
  }
}