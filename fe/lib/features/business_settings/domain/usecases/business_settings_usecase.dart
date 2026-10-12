import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/business_settings/domain/models/bar_details.dart';
import 'package:barz/features/business_settings/domain/models/contact_settings.dart';
import 'package:barz/features/business_settings/domain/models/delete_result.dart';
import 'package:barz/features/business_settings/domain/models/deactivate_result.dart';
import 'package:barz/features/business_settings/domain/models/reactivate_result.dart';
import 'package:barz/features/business_settings/domain/repositories/abstract_business_settings_repository.dart';

class BusinessSettingsUsecase {
  final BusinessSettingsRepositoryInterface _repository;

  BusinessSettingsUsecase(this._repository);

  Future<Either<Failure, BarDetails>> getBarDetails(int barId) {
    return _repository.getBarDetails(barId);
  }

  Future<Either<Failure, BarDetails>> updateBarDetails(
    int barId,
    Map<String, dynamic> data,
  ) {
    return _repository.updateBarDetails(barId, data);
  }

  Future<Either<Failure, ContactSettings>> getContactSettings(int barId) {
    return _repository.getContactSettings(barId);
  }

  Future<Either<Failure, ContactSettings>> updateContactSettings(
    int barId,
    Map<String, dynamic> data,
  ) {
    return _repository.updateContactSettings(barId, data);
  }

  Future<Either<Failure, DeleteResult>> deleteBusinessData(int barId) {
    return _repository.deleteBusinessData(barId);
  }

  Future<Either<Failure, DeactivateResult>> deactivateAccount(
    int barId, {
    String? reason,
    String? estimatedReturnDate,
  }) {
    return _repository.deactivateAccount(
      barId,
      reason: reason,
      estimatedReturnDate: estimatedReturnDate,
    );
  }

  Future<Either<Failure, ReactivateResult>> reactivateAccount(int barId) {
    return _repository.reactivateAccount(barId);
  }

  Future<Either<Failure, ({String url, int expiration})>> uploadBarImage(
    int barId, {
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _repository.uploadBarImage(barId, imageBytes: imageBytes, fileName: fileName);
  }
}
