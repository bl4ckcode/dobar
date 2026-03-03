import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/user_document.dart';

part 'user_event.freezed.dart';

@freezed
sealed class UserEvent with _$UserEvent {
  const factory UserEvent.loadCurrentUser() = LoadCurrentUser;
  const factory UserEvent.updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePictureUrl,
  }) = UpdateProfile;
  const factory UserEvent.updatePreferences(UserPreferences preferences) =
      UpdatePreferences;
  const factory UserEvent.addDocument(UserDocument document) = AddDocument;
  const factory UserEvent.removeDocument(int documentId) = RemoveDocument;
  const factory UserEvent.acceptTerms() = AcceptTerms;
  const factory UserEvent.acceptPrivacy() = AcceptPrivacy;
  const factory UserEvent.deleteAccount() = DeleteAccount;
  const factory UserEvent.loadWalletBalance() = LoadWalletBalance;
  const factory UserEvent.loadCashbackHistory() = LoadCashbackHistory;
  const factory UserEvent.clearError() = ClearUserError;
}
