import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'bar_access.dart';

/// Represents the complete user session in the Barz app.
///
/// This is the central model for determining which UI experience to show:
/// - User type is determined by `user.userType` from the backend profile
/// - Business users have [barAccess] populated with their bar list
///
/// The session is initialized after login by calling GET /me/profile
class UserSession {
  final UserModel user;
  final List<BarAccess> barAccess;
  final BarAccess? activeBar;

  const UserSession({
    required this.user,
    this.barAccess = const [],
    this.activeBar,
  });

  /// User type from the authenticated user profile
  UserType get userType => user.userType;

  /// Check if user is a client
  bool get isClient => userType.isClient;

  /// Check if user is a business user
  bool get isBusiness => userType.isBusiness;

  /// Check if user is an admin
  bool get isAdmin => userType.isAdmin;

  /// Check if user owns any bars
  bool get isBarOwner {
    return barAccess.any((access) => access.role == BarRole.owner);
  }

  /// Get all bars where user is an owner
  List<BarAccess> get ownedBars {
    return barAccess.where((access) => access.role == BarRole.owner).toList();
  }

  /// Get the highest role the user has across all bars
  BarRole? get highestRole {
    if (barAccess.isEmpty) return null;
    return barAccess
        .reduce((a, b) => a.role.hierarchyLevel < b.role.hierarchyLevel ? a : b)
        .role;
  }

  /// Check if user has a specific permission for the active bar
  bool hasPermission(Permission permission) {
    return activeBar?.hasPermission(permission) ?? false;
  }

  /// Check if user has any of the given permissions for the active bar
  bool hasAnyPermission(Set<Permission> permissions) {
    return activeBar?.hasAnyPermission(permissions) ?? false;
  }

  /// Create a new session with a different active bar
  UserSession withActiveBar(int barId) {
    final bar = barAccess.firstWhere(
      (access) => access.barId == barId,
      orElse: () => barAccess.first,
    );
    return UserSession(user: user, barAccess: barAccess, activeBar: bar);
  }

  /// Create a new session with updated bar access
  UserSession withBarAccess(List<BarAccess> newBarAccess) {
    return UserSession(
      user: user,
      barAccess: newBarAccess,
      activeBar: newBarAccess.isNotEmpty
          ? (activeBar != null
                ? newBarAccess.firstWhere(
                    (b) => b.barId == activeBar!.barId,
                    orElse: () => newBarAccess.first,
                  )
                : newBarAccess.first)
          : null,
    );
  }

  /// Create an empty session (for logged out state)
  static UserSession empty() {
    return UserSession(
      user: UserModel(
        id: 0,
        firebaseUid: '',
        preferences: UserPreferences(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      barAccess: const [],
    );
  }

  @override
  String toString() {
    return 'UserSession(userId: ${user.id}, userType: ${userType.name}, bars: ${barAccess.length}, activeBar: ${activeBar?.barName})';
  }
}
