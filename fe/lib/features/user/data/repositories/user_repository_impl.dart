import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/user/data/data_sources/user_network_datasource.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/user_document.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/models/cashback_transaction.dart';

class UserRepositoryImpl implements UserRepository {
  final UserDatasource _datasource;

  UserRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    try {
      final result = await _datasource.getCurrentUser();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getUserById(int id) async {
    try {
      final result = await _datasource.getUserById(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['display_name'] = displayName;
      if (email != null) data['email'] = email;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      if (avatarUrl != null) {
        data['avatar_url'] = avatarUrl;
      }
      final result = await _datasource.updateProfile(data);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, bool>> registerFcmToken(String token) async {
    try {
      await _datasource.registerFcmToken(token);
      return const Right(true);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>>
  getNotificationPreferences() async {
    try {
      final result = await _datasource.getNotificationPreferences();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>>
  updateNotificationPreferences(NotificationPreferences preferences) async {
    try {
      final result = await _datasource.updateNotificationPreferences(
        preferences,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PrivacySettings>> getPrivacySettings() async {
    try {
      final result = await _datasource.getPrivacySettings();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    PrivacySettings settings,
  ) async {
    try {
      final result = await _datasource.updatePrivacySettings(settings);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> addDocument(UserDocument document) async {
    try {
      final result = await _datasource.addDocument(document);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> removeDocument(int documentId) async {
    try {
      final result = await _datasource.removeDocument(documentId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> acceptTerms() async {
    try {
      final result = await _datasource.acceptTerms();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserModel>> acceptPrivacy() async {
    try {
      final result = await _datasource.acceptPrivacy();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteAccount() async {
    try {
      final result = await _datasource.deleteAccount();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, double>> getWalletBalance() async {
    try {
      final result = await _datasource.getWalletBalance();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<CashbackTransaction>>>
  getCashbackHistory() async {
    try {
      final result = await _datasource.getCashbackHistory();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }
}
