import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/business_settings/domain/models/bar_details.dart';
import 'package:barz/features/business_settings/domain/models/contact_settings.dart';
import 'package:barz/features/business_settings/domain/models/delete_result.dart';
import 'package:barz/features/business_settings/domain/models/deactivate_result.dart';
import 'package:barz/features/business_settings/domain/models/reactivate_result.dart';

part 'business_settings_state.freezed.dart';

@freezed
abstract class BusinessSettingsState with _$BusinessSettingsState {
  const factory BusinessSettingsState({
    BarDetails? barDetails,
    ContactSettings? contactSettings,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,
    String? error,
    DeleteResult? deleteResult,
    DeactivateResult? deactivateResult,
    ReactivateResult? reactivateResult,
  }) = _BusinessSettingsState;
}
