import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

/// Staff management page for bar owners/admins.
///
/// Features:
/// - View all staff members
/// - Invite new staff via email or phone
/// - Assign/change roles
/// - Remove staff members
class StaffManagementPage extends StatelessWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeBar = state.session.activeBar;
        if (activeBar == null) {
          return const Center(child: Text('No bar selected'));
        }

        return Scaffold(
          backgroundColor: barzGoldSoft,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'staff_invite_fab',
            onPressed: () => _showInviteDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Invite'),
            backgroundColor: barzGold,
            foregroundColor: barzDark,
          ),
          body: _buildStaffList(context),
        );
      },
    );
  }

  Widget _buildStaffList(BuildContext context) {
    // TODO: Fetch actual staff list
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Staff Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your team members and their roles',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _buildRoleInfo(),
        ],
      ),
    );
  }

  Widget _buildRoleInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Roles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...BarRole.values.map(
              (role) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getRoleIcon(role),
                      size: 20,
                      color: _getRoleColor(role),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            role.description,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(BarRole role) {
    switch (role) {
      case BarRole.owner:
        return Icons.star;
      case BarRole.admin:
        return Icons.admin_panel_settings;
      case BarRole.manager:
        return Icons.manage_accounts;
      case BarRole.cashier:
        return Icons.point_of_sale;
      case BarRole.staff:
        return Icons.person;
    }
  }

  Color _getRoleColor(BarRole role) {
    switch (role) {
      case BarRole.owner:
        return Colors.amber;
      case BarRole.admin:
        return Colors.purple;
      case BarRole.manager:
        return Colors.blue;
      case BarRole.cashier:
        return Colors.green;
      case BarRole.staff:
        return Colors.grey;
    }
  }

  void _showInviteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _InviteStaffSheet(),
    );
  }
}

class _InviteStaffSheet extends StatefulWidget {
  const _InviteStaffSheet();

  @override
  State<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends State<_InviteStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  BarRole _selectedRole = BarRole.staff;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Invite Staff Member',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email or Phone',
                hintText: 'Enter email or phone number',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email or phone';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Select Role'),
            const SizedBox(height: 8),
            DropdownButtonFormField<BarRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: BarRole.values
                  .where((role) => role != BarRole.owner)
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: barzGold,
                  foregroundColor: barzDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Send Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitInvitation() {
    if (_formKey.currentState!.validate()) {
      // TODO: Send invitation via API
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
    }
  }
}
