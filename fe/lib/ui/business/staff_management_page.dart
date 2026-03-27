import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/ui/business/widgets/business_toolbars.dart';
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
// Removed hardcoded _mockStaff list

import 'package:barz/features/staff/domain/models/bar_staff.dart';
import 'package:barz/features/staff/presentation/bloc/staff_bloc.dart';
import 'package:barz/features/staff/presentation/bloc/staff_event.dart';
import 'package:barz/features/staff/presentation/bloc/staff_state.dart';
import 'package:get_it/get_it.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  late StaffBloc _staffBloc;

  @override
  void initState() {
    super.initState();
    _staffBloc = GetIt.I<StaffBloc>();
  }

  @override
  void dispose() {
    _staffBloc.close();
    super.dispose();
  }

  void _changeRole(int barId, String staffId, BarRole newRole) {
    _staffBloc.add(
      StaffEvent.changeMemberRole(
        barId: barId,
        staffId: staffId,
        newRole: newRole.name,
      ),
    );
  }

  void _removeMember(int barId, String staffId) {
    _staffBloc.add(StaffEvent.removeMember(barId: barId, staffId: staffId));
  }

  void _inviteMember(int barId, String contact, BarRole role) {
    _staffBloc.add(
      StaffEvent.inviteMember(barId: barId, contact: contact, role: role.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MultiBlocProvider(
      providers: [BlocProvider.value(value: _staffBloc)],
      child: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, sessionState) {
          if (sessionState is! SessionReady) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeBar = sessionState.session.activeBar;
          if (activeBar == null) {
            return const Center(child: Text('No bar selected'));
          }

          // Initial Load
          if (_staffBloc.state == const StaffState.initial()) {
            _staffBloc.add(StaffEvent.loadStaff(barId: activeBar.barId));
          }

          final dobar = context.dobarColors;
          final isDark = theme.brightness == Brightness.dark;
          final bgColor = dobar.background;

          return Scaffold(
            backgroundColor: bgColor,
            body: BlocConsumer<StaffBloc, StaffState>(
              listener: (context, state) {
                state.maybeWhen(
                  error: (msg) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: Colors.red),
                    );
                  },
                  actionSuccess: (message, _) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  orElse: () {},
                );
              },
              builder: (context, staffState) {
                return ResponsiveCenterContainer(
                  maxWidthPercentage: 0.8,
                  maxWidth: 1200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarzSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark, staffState, activeBar.barId),
                      Expanded(
                        child: staffState.maybeWhen(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          loaded: (staffList) => _buildStaffList(
                            staffList,
                            activeBar.barId,
                            isDark,
                          ),
                          actionSuccess: (_, staffList) => _buildStaffList(
                            staffList,
                            activeBar.barId,
                            isDark,
                          ),
                          orElse: () => const Center(
                            child: Text('No staff data available'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffList(List<BarStaff> staffList, int barId, bool isDark) {
    if (staffList.isEmpty) {
      return const Center(child: Text('No staff members found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: BarzSpacing.xl),
      itemCount: staffList.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: BarzSpacing.sm),
      itemBuilder: (context, index) {
        final member = staffList[index];
        return _StaffRow(
          member: member,
          isDark: isDark,
          onChangeRole: (role) => _changeRole(barId, member.id, role),
          onRemove: () => _removeMember(barId, member.id),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, StaffState staffState, int barId) {
    final staffCount = staffState.maybeWhen(
      loaded: (list) => list.length,
      actionSuccess: (_, list) => list.length,
      orElse: () => 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return BusinessActionToolbar(
          title: 'Staff',
          subtitle: staffState.maybeWhen(
            initial: () => null,
            loading: () => null,
            orElse: () => '$staffCount members',
          ),
          icon: LucideIcons.users,
          isNarrow: constraints.maxWidth < 600,
          actions: [
            FilledButton.icon(
              onPressed: () => _showInviteDialog(context, barId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Invite Staff'),
              style: FilledButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: BarzSpacing.md,
                  vertical: BarzSpacing.sm,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInviteDialog(BuildContext context, int barId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dobarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InviteStaffSheet(
        isDark: isDark,
        onInvite: (contact, role) => _inviteMember(barId, contact, role),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final BarStaff member;
  final bool isDark;
  final void Function(BarRole) onChangeRole;
  final VoidCallback onRemove;

  const _StaffRow({
    required this.member,
    required this.isDark,
    required this.onChangeRole,
    required this.onRemove,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final cardBg = dobar.surface;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;
    final avatarBg = dobar.surfaceElevated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              _getInitials(member.name),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: dobar.labelPrimary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.email}${member.email.isNotEmpty && member.phone.isNotEmpty ? ' · ' : ''}${member.phone}',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _RoleBadge(role: member.role),
          const SizedBox(width: 8),
          Theme(
            data: theme.copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: dobar.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: mutedColor),
              tooltip: 'More actions',
              offset: const Offset(0, 40),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'change_role',
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: textColor),
                      const SizedBox(width: 8),
                      Text(
                        'Change Role',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 16, color: mutedColor),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'remove',
                  height: 40,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: errorRed,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Remove',
                        style: TextStyle(color: errorRed, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'change_role') {
                  _showRoleSelector(context, dobar);
                } else if (value == 'remove') {
                  onRemove();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleSelector(BuildContext ctx, DobarColors dobar) {
    final renderBox = ctx.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<BarRole>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        offset.dx + size.width - 200,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height + 200,
      ),
      color: dobar.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: BarRole.values
          .map(
            (r) => PopupMenuItem<BarRole>(
              value: r,
              height: 40,
              child: Text(
                r.displayName,
                style: TextStyle(
                  color: member.role == r ? barzGold : dobar.labelPrimary,
                  fontSize: 13,
                  fontWeight: member.role == r
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    ).then((selected) {
      if (selected != null) {
        onChangeRole(selected);
      }
    });
  }
}

class _RoleBadge extends StatelessWidget {
  final BarRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    switch (role) {
      case BarRole.owner:
        baseColor = const Color(0xFFFFD700); // Pure Gold
        break;
      case BarRole.admin:
        baseColor = const Color(0xFFC0C0C0); // Silver
        break;
      case BarRole.manager:
        baseColor = const Color(0xFFCD7F32); // Bronze
        break;
      case BarRole.cashier:
        baseColor = const Color(0xFF9E9E9E); // Platinum/Gray
        break;
      case BarRole.staff:
        baseColor = const Color(0xFF757575); // Steel
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: baseColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InviteStaffSheet extends StatefulWidget {
  final bool isDark;
  final void Function(String, BarRole) onInvite;

  const _InviteStaffSheet({required this.isDark, required this.onInvite});

  @override
  State<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends State<_InviteStaffSheet> {
  final _contactController = TextEditingController();
  BarRole _selectedRole = BarRole.staff;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) return;
    widget.onInvite(contact, _selectedRole);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dobar = context.dobarColors;
    final textColor = dobar.labelPrimary;
    final mutedColor = dobar.labelSecondary;
    final inputBg = dobar.surfaceElevated;
    final borderColor = theme.colorScheme.outline;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Staff',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Space Grotesk',
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: mutedColor, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: dobar.surfaceElevated,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Contact Input
          Text(
            'Email or Phone',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _contactController,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'name@email.com or +1 555-0000',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: barzGold.withValues(alpha: 0.5)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Role Select
          Text(
            'Assign Role',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<BarRole>(
            initialValue: _selectedRole,
            dropdownColor: dobar.surface,
            style: TextStyle(color: textColor, fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down, color: mutedColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: barzGold.withValues(alpha: 0.5)),
              ),
            ),
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
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _contactController.text.trim().isEmpty
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: barzGold,
                foregroundColor: barzDark,
                disabledBackgroundColor: barzGold.withValues(alpha: 0.5),
                disabledForegroundColor: barzDark.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Send Invitation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
