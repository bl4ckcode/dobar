/// RBAC (Role-Based Access Control) module for Barz.
///
/// This module provides the foundation for the dual-app architecture,
/// allowing the same app to serve both bar clients and business users.
///
/// Key components:
/// - [UserType]: Client vs Business user differentiation
/// - [BarRole]: Hierarchical roles within a bar (owner > admin > manager > cashier > staff)
/// - [Permission]: Granular permissions for access control
library;

export 'user_type.dart';
export 'bar_role.dart';
export 'permission.dart';
