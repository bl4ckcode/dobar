/// Defines the type of user account in the Barz app.
/// 
/// The app serves two main user experiences:
/// - [client]: Regular bar-goers who browse, order, track orders, and earn cashback
/// - [business]: Bar owners/staff who manage bars, orders, staff, and billing
enum UserType {
  client,
  business,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.client:
        return 'Customer';
      case UserType.business:
        return 'Business';
    }
  }

  bool get isClient => this == UserType.client;
  bool get isBusiness => this == UserType.business;
}
