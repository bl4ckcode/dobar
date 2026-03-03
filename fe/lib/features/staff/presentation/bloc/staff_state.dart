import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/models/bar_staff.dart';

part 'staff_state.freezed.dart';

@freezed
class StaffState with _$StaffState {
  const factory StaffState.initial() = _Initial;
  const factory StaffState.loading() = _Loading;
  const factory StaffState.loaded({required List<BarStaff> staffMembers}) =
      _Loaded;
  const factory StaffState.error({required String message}) = _Error;
  const factory StaffState.actionSuccess({
    required String message,
    required List<BarStaff> staffMembers,
  }) = _ActionSuccess;
}
