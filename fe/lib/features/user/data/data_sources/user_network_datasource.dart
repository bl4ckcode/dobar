import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/features/user/domain/models/cashback_transaction.dart';
import 'package:dio/dio.dart';

abstract class UserDatasource {
  Future<UserModel> getCurrentUser();
  Future<UserModel> getUserById(int id);
  Future<UserModel> updateProfile(Map<String, dynamic> data);
  Future<NotificationPreferences> getNotificationPreferences();
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  );
  Future<PrivacySettings> getPrivacySettings();
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings);
  Future<UserModel> addDocument(UserDocument document);
  Future<UserModel> removeDocument(int documentId);
  Future<UserModel> acceptTerms();
  Future<UserModel> acceptPrivacy();
  Future<bool> deleteAccount();
  Future<bool> registerFcmToken(String token);
  Future<double> getWalletBalance();
  Future<List<CashbackTransaction>> getCashbackHistory();
}

class UserNetworkDatasource implements UserDatasource {
  final Dio dio;

  UserNetworkDatasource({required this.dio});

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userProfile}',
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get user',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> getUserById(int id) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.users}/$id',
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get user',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userProfile}',
        data: data,
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to update profile',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notificationPreferences}',
      );
      return NotificationPreferences.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get notification preferences',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.notificationPreferences}',
        data: preferences.toJson(),
      );
      return NotificationPreferences.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ??
            'Failed to update notification preferences',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PrivacySettings> getPrivacySettings() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.privacySettings}',
      );
      return PrivacySettings.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get privacy settings',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<PrivacySettings> updatePrivacySettings(
    PrivacySettings settings,
  ) async {
    try {
      final response = await dio.put(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.privacySettings}',
        data: settings.toJson(),
      );
      return PrivacySettings.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to update privacy settings',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> addDocument(UserDocument document) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userDocuments}',
        data: document.toJson(),
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to add document',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> removeDocument(int documentId) async {
    try {
      final response = await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userDocuments}/$documentId',
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to remove document',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> acceptTerms() async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userAcceptTerms}',
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to accept terms',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> acceptPrivacy() async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userAcceptPrivacy}',
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to accept privacy',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<bool> deleteAccount() async {
    try {
      await dio.delete(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userDataExclusion}',
      );
      return true;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to delete account',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<bool> registerFcmToken(String token) async {
    try {
      await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.fcmToken}',
        data: {'token': token},
      );
      return true;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to register FCM token',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<double> getWalletBalance() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userWallet}',
      );
      return (response.data['balance'] as num).toDouble();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get wallet balance',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<CashbackTransaction>> getCashbackHistory() async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.userCashback}',
      );
      return (response.data as List)
          .map((json) => CashbackTransaction.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['detail'] ?? 'Failed to get cashback history',
        e.response?.statusCode,
      );
    }
  }
}
