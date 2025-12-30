import 'user_document.dart';

class UserModel {
  final int id;
  final String firebaseUid;
  final String? phoneNumber;
  final String? email;
  final String? displayName;
  final String? profilePictureUrl;
  final List<UserDocument> documents;
  final UserPreferences preferences;
  final double walletBalance;
  final double totalCashback;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final bool privacyAccepted;
  final DateTime? privacyAcceptedAt;
  final bool isActive;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.firebaseUid,
    this.phoneNumber,
    this.email,
    this.displayName,
    this.profilePictureUrl,
    this.documents = const [],
    required this.preferences,
    this.walletBalance = 0.0,
    this.totalCashback = 0.0,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.privacyAccepted = false,
    this.privacyAcceptedAt,
    this.isActive = true,
    this.isPremium = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      firebaseUid: json['firebase_uid'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      displayName: json['display_name'],
      profilePictureUrl: json['profile_picture_url'],
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => UserDocument.fromJson(e))
              .toList() ??
          [],
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : UserPreferences(),
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      totalCashback: (json['total_cashback'] as num?)?.toDouble() ?? 0.0,
      termsAccepted: json['terms_accepted'] ?? false,
      termsAcceptedAt: json['terms_accepted_at'] != null
          ? DateTime.parse(json['terms_accepted_at'])
          : null,
      privacyAccepted: json['privacy_accepted'] ?? false,
      privacyAcceptedAt: json['privacy_accepted_at'] != null
          ? DateTime.parse(json['privacy_accepted_at'])
          : null,
      isActive: json['is_active'] ?? true,
      isPremium: json['is_premium'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'phone_number': phoneNumber,
      'email': email,
      'display_name': displayName,
      'profile_picture_url': profilePictureUrl,
      'documents': documents.map((e) => e.toJson()).toList(),
      'preferences': preferences.toJson(),
      'wallet_balance': walletBalance,
      'total_cashback': totalCashback,
      'terms_accepted': termsAccepted,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
      'privacy_accepted': privacyAccepted,
      'privacy_accepted_at': privacyAcceptedAt?.toIso8601String(),
      'is_active': isActive,
      'is_premium': isPremium,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UserPreferences {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool locationSharing;
  final String preferredLanguage;
  final String preferredCurrency;

  UserPreferences({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.locationSharing = true,
    this.preferredLanguage = 'pt-BR',
    this.preferredCurrency = 'BRL',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      pushNotifications: json['push_notifications'] ?? true,
      emailNotifications: json['email_notifications'] ?? true,
      smsNotifications: json['sms_notifications'] ?? false,
      locationSharing: json['location_sharing'] ?? true,
      preferredLanguage: json['preferred_language'] ?? 'pt-BR',
      preferredCurrency: json['preferred_currency'] ?? 'BRL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_notifications': pushNotifications,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'location_sharing': locationSharing,
      'preferred_language': preferredLanguage,
      'preferred_currency': preferredCurrency,
    };
  }
}
