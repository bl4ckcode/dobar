import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_settings_event.freezed.dart';

@freezed
sealed class BusinessSettingsEvent with _$BusinessSettingsEvent {
  const factory BusinessSettingsEvent.loadBarDetails(int barId) =
      LoadBarDetails;
  const factory BusinessSettingsEvent.updateBarDetails(
    int barId,
    Map<String, dynamic> data,
  ) = UpdateBarDetails;
  const factory BusinessSettingsEvent.loadContactSettings(int barId) =
      LoadContactSettings;
  const factory BusinessSettingsEvent.updateContactSettings(
    int barId,
    Map<String, dynamic> data,
  ) = UpdateContactSettings;
  const factory BusinessSettingsEvent.deleteBusinessData(int barId) =
      DeleteBusinessData;
  const factory BusinessSettingsEvent.deactivateAccount(
    int barId, {
    String? reason,
    String? estimatedReturnDate,
  }) = DeactivateAccount;
  const factory BusinessSettingsEvent.reactivateAccount(int barId) =
      ReactivateAccount;
  const factory BusinessSettingsEvent.clearError() = ClearError;
  const factory BusinessSettingsEvent.uploadBarImage(
    int barId, {
    required Uint8List imageBytes,
    required String fileName,
  }) = UploadBarImage;
}
