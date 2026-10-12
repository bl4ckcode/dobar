import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/business_settings/domain/models/bar_details.dart';
import 'package:barz/features/business_settings/domain/models/contact_settings.dart';
import 'package:barz/features/business_settings/domain/models/delete_result.dart';
import 'package:barz/features/business_settings/domain/models/deactivate_result.dart';
import 'package:barz/features/business_settings/domain/models/reactivate_result.dart';

abstract class BusinessSettingsRepositoryInterface {
  Future<Either<Failure, BarDetails>> getBarDetails(int barId);
  Future<Either<Failure, BarDetails>> updateBarDetails(
    int barId,
    Map<String, dynamic> data,
  );
  Future<Either<Failure, ContactSettings>> getContactSettings(int barId);
  Future<Either<Failure, ContactSettings>> updateContactSettings(
    int barId,
    Map<String, dynamic> data,
  );
  Future<Either<Failure, DeleteResult>> deleteBusinessData(int barId);
  Future<Either<Failure, DeactivateResult>> deactivateAccount(
    int barId, {
    String? reason,
    String? estimatedReturnDate,
  });
  Future<Either<Failure, ReactivateResult>> reactivateAccount(int barId);
  Future<Either<Failure, ({String url, int expiration})>> uploadBarImage(
    int barId, {
    required Uint8List imageBytes,
    required String fileName,
  });
}
