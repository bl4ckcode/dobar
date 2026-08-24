import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/ui/business/widgets/business_toolbars.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
            return Center(child: Text(AppLocalizations.of(context)!.business_no_bar_selected));
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
                          orElse: () => Center(
                            child: Text(l10n.business_staff_no_data),
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
    final l10n = AppLocalizations.of(context)!;
    if (staffList.isEmpty) {
      return Center(child: Text(l10n.business_staff_no_members));
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
    final l10n = AppLocalizations.of(context)!;
    final staffCount = staffState.maybeWhen(
      loaded: (list) => list.length,
      actionSuccess: (_, list) => list.length,
      orElse: () => 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return BusinessActionToolbar(
          title: l10n.business_staff_title,
          subtitle: staffState.maybeWhen(
            initial: () => null,
            loading: () => null,
            orElse: () => l10n.business_staff_members(staffCount),
          ),
          icon: LucideIcons.users,
          isNarrow: constraints.maxWidth < 600,
          actions: [
            FilledButton.icon(
              onPressed: () => _showInviteDialog(context, barId),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.business_invite_staff),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

class _StaffRow extends StatefulWidget {
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

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _isHovered = false;

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Reference staff-hub HSL Colors
    // Light Mode variables:
    // --background: 40 20% 96%;
    // --foreground: 0 0% 12%;
    // --card: 0 0% 100%;
    // --secondary: 40 10% 90%;
    // --muted: 40 10% 92%;
    // --muted-foreground: 0 0% 45%;

    // Dark Mode variables:
    // --background: 0 0% 7%;
    // --foreground: 0 0% 95%;
    // --card: 0 0% 12%;
    // --secondary: 0 0% 18%;
    // --muted: 0 0% 15%;
    // --muted-foreground: 0 0% 55%;

    final cardBg = widget.isDark
        ? HSLColor.fromAHSL(1.0, 0, 0, 0.12).toColor()
        : HSLColor.fromAHSL(1.0, 0, 0, 1.0).toColor();

    final hoverBg = widget.isDark
        ? HSLColor.fromAHSL(0.5, 0, 0, 0.18)
              .toColor() // secondary/50
        : HSLColor.fromAHSL(0.5, 40, 0.1, 0.9).toColor();

    final textColor = widget.isDark
        ? HSLColor.fromAHSL(1.0, 0, 0, 0.95).toColor()
        : HSLColor.fromAHSL(1.0, 0, 0, 0.12).toColor();

    final mutedTextColor = widget.isDark
        ? HSLColor.fromAHSL(1.0, 0, 0, 0.55).toColor()
        : HSLColor.fromAHSL(1.0, 0, 0, 0.45).toColor();

    final avatarBg = widget.isDark
        ? HSLColor.fromAHSL(1.0, 0, 0, 0.18).toColor()
        : HSLColor.fromAHSL(1.0, 40, 0.1, 0.9).toColor();

    final avatarTextColor = widget.isDark
        ? HSLColor.fromAHSL(1.0, 0, 0, 0.75).toColor()
        : HSLColor.fromAHSL(1.0, 0, 0, 0.35).toColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? hoverBg : cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _getInitials(widget.member.name),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: avatarTextColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.member.name,
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
                    '${widget.member.email}${widget.member.email.isNotEmpty && widget.member.phone.isNotEmpty ? ' · ' : ''}${widget.member.phone}',
                    style: TextStyle(fontSize: 12, color: mutedTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _RoleBadge(role: widget.member.role, isDark: widget.isDark),
            const SizedBox(width: 8),
            // Actions Menu
            Opacity(
              opacity: _isHovered ? 1.0 : 0.0,
              child: _buildActionMenu(
                context,
                cardBg,
                textColor,
                mutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    Color menuBg,
    Color textColor,
    Color mutedTextColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return MenuAnchor(
      alignmentOffset: const Offset(-150, 0),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(menuBg),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: widget.isDark
                  ? HSLColor.fromAHSL(1.0, 0, 0, 0.18).toColor()
                  : HSLColor.fromAHSL(1.0, 40, 0.1, 0.85).toColor(),
            ),
          ),
        ),
      ),
      menuChildren: [
        SubmenuButton(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(menuBg),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: widget.isDark
                      ? HSLColor.fromAHSL(1.0, 0, 0, 0.18).toColor()
                      : HSLColor.fromAHSL(1.0, 40, 0.1, 0.85).toColor(),
                ),
              ),
            ),
          ),
          leadingIcon: Icon(Icons.shield_outlined, size: 16, color: textColor),
          menuChildren: BarRole.values.map((role) {
            final isCurrent = widget.member.role == role;
            final primaryColor = widget.isDark
                ? HSLColor.fromAHSL(1.0, 50, 1.0, 0.67).toColor()
                : HSLColor.fromAHSL(1.0, 50, 1.0, 0.50).toColor();
            return MenuItemButton(
              onPressed: () => widget.onChangeRole(role),
              child: Text(
                role.displayName,
                style: TextStyle(
                  color: isCurrent ? primaryColor : textColor,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          child: Text(
            l10n.business_change_role,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
        ),
        const PopupMenuDivider(),
        MenuItemButton(
          onPressed: widget.onRemove,
          leadingIcon: const Icon(
            Icons.delete_outline,
            size: 16,
            color: Colors.redAccent,
          ),
          child: Text(
            l10n.business_remove,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(Icons.more_vert, size: 16, color: mutedTextColor),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          hoverColor: widget.isDark
              ? HSLColor.fromAHSL(1.0, 0, 0, 0.18).toColor()
              : HSLColor.fromAHSL(1.0, 40, 0.1, 0.9).toColor(),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final BarRole role;
  final bool isDark;

  const _RoleBadge({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Reference CSS:
    // Light
    // --role-owner: 50 100% 40%;
    // --role-admin: 220 70% 50%;
    // --role-manager: 160 60% 38%;
    // --role-cashier: 280 50% 50%;
    // --role-staff: 0 0% 50%;

    // Dark
    // --role-owner: 50 100% 67%;
    // --role-admin: 220 70% 55%;
    // --role-manager: 160 60% 45%;
    // --role-cashier: 280 50% 55%;
    // --role-staff: 0 0% 45%;

    HSLColor hslColor;
    switch (role) {
      case BarRole.owner:
        hslColor = isDark
            ? HSLColor.fromAHSL(1.0, 50, 1.0, 0.67)
            : HSLColor.fromAHSL(1.0, 50, 1.0, 0.40);
        break;
      case BarRole.admin:
        hslColor = isDark
            ? HSLColor.fromAHSL(1.0, 220, 0.70, 0.55)
            : HSLColor.fromAHSL(1.0, 220, 0.70, 0.50);
        break;
      case BarRole.manager:
        hslColor = isDark
            ? HSLColor.fromAHSL(1.0, 160, 0.60, 0.45)
            : HSLColor.fromAHSL(1.0, 160, 0.60, 0.38);
        break;
      case BarRole.cashier:
        hslColor = isDark
            ? HSLColor.fromAHSL(1.0, 280, 0.50, 0.55)
            : HSLColor.fromAHSL(1.0, 280, 0.50, 0.50);
        break;
      case BarRole.staff:
        hslColor = isDark
            ? HSLColor.fromAHSL(1.0, 0, 0.0, 0.45)
            : HSLColor.fromAHSL(1.0, 0, 0.0, 0.50);
        break;
    }

    final baseColor = hslColor.toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: baseColor,
          fontSize: 12, // text-xs
          fontWeight: FontWeight.w500, // font-medium
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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.business_invite_staff_title,
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
            l10n.business_invite_email_phone,
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
              hintText: l10n.business_invite_email_hint,
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
            l10n.business_assign_role,
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
              child: Text(
                l10n.business_send_invitation,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
