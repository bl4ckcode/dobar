import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/components/responsive_center_container.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_reader_page.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

class MenuManagementPage extends StatelessWidget {
  const MenuManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final activeBar = state.currentSession?.activeBar;
        
        return Container(
          color: barzCream,
          child: ResponsiveCenterContainer(
            maxWidthPercentage: 0.6,
            maxWidth: 800,
            padding: const EdgeInsets.all(24),
            child: Center(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Manual item creation coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
                    onPressed: activeBar != null
                        ? () => _openMenuReader(context, activeBar.barId)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Menu (AI)'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMenuReader(BuildContext context, int barId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => getItInjector<MenuReaderBloc>(),
          child: MenuReaderPage(
            barId: barId,
            menuId: 0,
          ),
        ),
      ),
    );
  }
}
