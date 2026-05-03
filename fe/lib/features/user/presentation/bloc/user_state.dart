import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/models/cashback_transaction.dart';

part 'user_state.freezed.dart';

@freezed
abstract class UserState with _$UserState {
  const factory UserState({
    UserModel? user,
    @Default(false) bool isLoading,
    @Default(false) bool isUpdating,
    String? error,
    @Default(false) bool isCountryUpdated,
    @Default([]) List<CashbackTransaction> cashbackHistory,
    double? walletBalance,
  }) = _UserState;
}
