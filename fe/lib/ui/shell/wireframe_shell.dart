import 'package:flutter/material.dart';
import '../screens/home_wireframe.dart';
import '../screens/find_wireframe.dart';
import '../screens/profile_wireframe.dart';
import '../screens/login_wireframe.dart';
import '../../core/utils/constant/colors.dart';

class WireframeShell extends StatefulWidget {
  const WireframeShell({super.key});

  @override
  State<WireframeShell> createState() => _WireframeShellState();
}

class _WireframeShellState extends State<WireframeShell> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    HomeWireframe(),
    FindWireframe(),
    ProfileWireframe(),
    LoginWireframe(), // Added LoginWireframe to the pages
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: barzBlack,
        selectedItemColor: barzYellow,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Login'), // Added Login item
        ],
      ),
    );
  }
}