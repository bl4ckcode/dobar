import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/models/cashback_transaction.dart';

abstract class UserRepository {
  Future<Either<Failure, UserModel>> getCurrentUser();
  Future<Either<Failure, UserModel>> getUserById(int id);
  Future<Either<Failure, UserModel>> updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePictureUrl,
  });

  Future<Either<Failure, NotificationPreferences>> getNotificationPreferences();
  Future<Either<Failure, NotificationPreferences>>
  updateNotificationPreferences(NotificationPreferences preferences);

  Future<Either<Failure, PrivacySettings>> getPrivacySettings();
  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    PrivacySettings settings,
  );

  Future<Either<Failure, UserModel>> addDocument(UserDocument document);
  Future<Either<Failure, UserModel>> removeDocument(int documentId);
  Future<Either<Failure, UserModel>> acceptTerms();
  Future<Either<Failure, UserModel>> acceptPrivacy();
  Future<Either<Failure, bool>> deleteAccount();
  Future<Either<Failure, double>> getWalletBalance();
  Future<Either<Failure, List<CashbackTransaction>>> getCashbackHistory();
}
