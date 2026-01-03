import 'package:flutter/material.dart';
import 'package:barz/core/utils/constant/colors.dart';

/// Menu management page for bar owners/managers.
/// 
/// Features:
/// - View all menu categories and items
/// - Add/edit/delete menu items
/// - Toggle item availability
/// - AI Menu Parser (take photo → parse menu)
class MenuManagementPage extends StatelessWidget {
  const MenuManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Menu Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your menu items and categories',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Add new menu item
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: barzYellow,
                foregroundColor: barzBlack,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Open AI Menu Parser
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Menu (AI)'),
            ),
          ],
        ),
      ),
    );
  }
}
