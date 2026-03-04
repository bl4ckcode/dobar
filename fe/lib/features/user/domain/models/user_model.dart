import 'package:barz/core/rbac/user_type.dart';
import 'user_document.dart';

class UserModel {
  final int? id;
  final String? firebaseUid;
  final String? phoneNumber;
  final String? email;
  final String? displayName;
  final String? profilePictureUrl;
  final List<UserDocument> documents;
  final double walletBalance;
  final double totalCashback;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final bool privacyAccepted;
  final DateTime? privacyAcceptedAt;
  final bool isActive;
  final bool isPremium;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserType userType;
  final String? countryCode;

  /// Check if user has completed onboarding (has country set)
  bool get hasCompletedOnboarding => countryCode != null;

  UserModel({
    this.id,
    this.firebaseUid,
    this.phoneNumber,
    this.email,
    this.displayName,
    this.profilePictureUrl,
    this.documents = const [],
    this.walletBalance = 0.0,
    this.totalCashback = 0.0,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.privacyAccepted = false,
    this.privacyAcceptedAt,
    this.isActive = true,
    this.isPremium = false,
    this.createdAt,
    this.updatedAt,
    this.userType = UserType.client,
    this.countryCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      firebaseUid: json['firebase_uid'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      // Handle both 'profile_picture_url' and 'avatar_url' keys
      profilePictureUrl:
          (json['profile_picture_url'] ?? json['avatar_url']) as String?,
      documents:
          (json['documents'] as List<dynamic>?)
              ?.map((e) => UserDocument.fromJson(e))
              .toList() ??
          [],
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userType: UserType.fromString(json['user_type'] as String?),
      countryCode: json['country_code'] as String?,
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
      'wallet_balance': walletBalance,
      'total_cashback': totalCashback,
      'terms_accepted': termsAccepted,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
      'privacy_accepted': privacyAccepted,
      'privacy_accepted_at': privacyAcceptedAt?.toIso8601String(),
      'is_active': isActive,
      'is_premium': isPremium,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_type': userType.name,
    };
  }
}
