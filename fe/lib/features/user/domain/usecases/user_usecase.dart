import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/features/user/domain/models/cashback_transaction.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';

class UserUsecase {
  final UserRepository _repository;

  UserUsecase(this._repository);

  Future<Either<Failure, UserModel>> getCurrentUser() {
    return _repository.getCurrentUser();
  }

  Future<Either<Failure, UserModel>> getUserById(int id) {
    return _repository.getUserById(id);
  }

  Future<Either<Failure, UserModel>> updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePictureUrl,
  }) {
    return _repository.updateProfile(
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      profilePictureUrl: profilePictureUrl,
    );
  }

  Future<Either<Failure, NotificationPreferences>>
  getNotificationPreferences() {
    return _repository.getNotificationPreferences();
  }

  Future<Either<Failure, NotificationPreferences>>
  updateNotificationPreferences(NotificationPreferences preferences) {
    return _repository.updateNotificationPreferences(preferences);
  }

  Future<Either<Failure, PrivacySettings>> getPrivacySettings() {
    return _repository.getPrivacySettings();
  }

  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    PrivacySettings settings,
  ) {
    return _repository.updatePrivacySettings(settings);
  }

  Future<Either<Failure, UserModel>> addDocument(UserDocument document) {
    return _repository.addDocument(document);
  }

  Future<Either<Failure, UserModel>> removeDocument(int documentId) {
    return _repository.removeDocument(documentId);
  }

  Future<Either<Failure, UserModel>> acceptTerms() {
    return _repository.acceptTerms();
  }

  Future<Either<Failure, UserModel>> acceptPrivacy() {
    return _repository.acceptPrivacy();
  }

  Future<Either<Failure, bool>> deleteAccount() {
    return _repository.deleteAccount();
  }

  Future<Either<Failure, double>> getWalletBalance() {
    return _repository.getWalletBalance();
  }

  Future<Either<Failure, List<CashbackTransaction>>> getCashbackHistory() {
    return _repository.getCashbackHistory();
  }
}
