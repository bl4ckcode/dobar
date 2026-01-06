/// Defines the type of user account in the Barz app.
/// 
/// The app serves different user experiences:
/// - [client]: Regular bar-goers who browse, order, track orders, and earn cashback
/// - [business]: Bar owners/staff who manage bars, orders, staff, and billing
/// - [admin]: Administrative users with elevated privileges
enum UserType {
  client,
  business,
  admin;

  /// Parse user type from backend string
  static UserType fromString(String? value) {
    switch (value) {
      case 'business':
        return UserType.business;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.client;
    }
  }
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.client:
        return 'Customer';
      case UserType.business:
        return 'Business';
      case UserType.admin:
        return 'Admin';
    }
  }

  bool get isClient => this == UserType.client;
  bool get isBusiness => this == UserType.business;
  bool get isAdmin => this == UserType.admin;
}
