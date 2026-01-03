import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

/// A widget that conditionally renders its child based on user permissions.
/// 
/// This widget is used to show/hide UI elements based on the current user's
/// permissions for the active bar.
/// 
/// Example:
/// ```dart
/// RoleGuard(
///   permission: Permission.menuEdit,
///   child: ElevatedButton(
///     onPressed: () => editMenu(),
///     child: Text('Edit Menu'),
///   ),
/// )
/// ```
class RoleGuard extends StatelessWidget {
  /// The permission required to show the child widget
  final Permission? permission;

  /// Multiple permissions - show if user has ANY of these
  final Set<Permission>? anyOf;

  /// Multiple permissions - show if user has ALL of these
  final Set<Permission>? allOf;

  /// The widget to show if the user has the required permission(s)
  final Widget child;

  /// Optional widget to show if the user doesn't have permission
  final Widget? fallback;

  /// Minimum role required (uses role hierarchy)
  final BarRole? minRole;

  /// Only show for business users
  final bool businessOnly;

  /// Only show for client users
  final bool clientOnly;

  const RoleGuard({
    super.key,
    this.permission,
    this.anyOf,
    this.allOf,
    required this.child,
    this.fallback,
    this.minRole,
    this.businessOnly = false,
    this.clientOnly = false,
  }) : assert(
          permission != null || anyOf != null || allOf != null || minRole != null || businessOnly || clientOnly,
          'At least one permission condition must be specified',
        );

  /// Convenience constructor for business-only content
  const RoleGuard.business({
    super.key,
    required this.child,
    this.fallback,
  })  : permission = null,
        anyOf = null,
        allOf = null,
        minRole = null,
        businessOnly = true,
        clientOnly = false;

  /// Convenience constructor for client-only content
  const RoleGuard.client({
    super.key,
    required this.child,
    this.fallback,
  })  : permission = null,
        anyOf = null,
        allOf = null,
        minRole = null,
        businessOnly = false,
        clientOnly = true;

  /// Convenience constructor for owner-only content
  const RoleGuard.owner({
    super.key,
    required this.child,
    this.fallback,
  })  : permission = null,
        anyOf = null,
        allOf = null,
        minRole = BarRole.owner,
        businessOnly = false,
        clientOnly = false;

  /// Convenience constructor for manager+ content
  const RoleGuard.manager({
    super.key,
    required this.child,
    this.fallback,
  })  : permission = null,
        anyOf = null,
        allOf = null,
        minRole = BarRole.manager,
        businessOnly = false,
        clientOnly = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionReady) {
          return fallback ?? const SizedBox.shrink();
        }

        final session = state.session;
        final activeBar = session.activeBar;
        final effectiveUserType = state.effectiveUserType;

        // Check client-only
        if (clientOnly && effectiveUserType != UserType.client) {
          return fallback ?? const SizedBox.shrink();
        }

        // Check business-only
        if (businessOnly && effectiveUserType != UserType.business) {
          return fallback ?? const SizedBox.shrink();
        }

        // For business users, check permissions
        if (effectiveUserType == UserType.business && activeBar != null) {
          // Check minimum role
          if (minRole != null) {
            if (!activeBar.role.hasPrivilegeOver(minRole!)) {
              return fallback ?? const SizedBox.shrink();
            }
          }

          // Check single permission
          if (permission != null) {
            if (!activeBar.hasPermission(permission!)) {
              return fallback ?? const SizedBox.shrink();
            }
          }

          // Check anyOf permissions
          if (anyOf != null && anyOf!.isNotEmpty) {
            if (!activeBar.hasAnyPermission(anyOf!)) {
              return fallback ?? const SizedBox.shrink();
            }
          }

          // Check allOf permissions
          if (allOf != null && allOf!.isNotEmpty) {
            if (!activeBar.hasAllPermissions(allOf!)) {
              return fallback ?? const SizedBox.shrink();
            }
          }
        }

        return child;
      },
    );
  }
}

/// Extension for easily checking permissions in widget builds
extension SessionStatePermissions on SessionState {
  bool hasPermission(Permission permission) {
    final state = this;
    if (state is! SessionReady) return false;
    return state.session.activeBar?.hasPermission(permission) ?? false;
  }

  bool hasAnyPermission(Set<Permission> permissions) {
    final state = this;
    if (state is! SessionReady) return false;
    return state.session.activeBar?.hasAnyPermission(permissions) ?? false;
  }

  bool hasRole(BarRole role) {
    final state = this;
    if (state is! SessionReady) return false;
    final activeBar = state.session.activeBar;
    if (activeBar == null) return false;
    return activeBar.role.hasPrivilegeOver(role);
  }
}
