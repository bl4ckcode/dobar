import 'package:freezed_annotation/freezed_annotation.dart';

part 'staff_event.freezed.dart';

@freezed
abstract class StaffEvent with _$StaffEvent {
  const factory StaffEvent.loadStaff({required int barId}) = _LoadStaff;

  const factory StaffEvent.inviteMember({
    required int barId,
    required String contact,
    required String role,
  }) = _InviteMember;

  const factory StaffEvent.changeMemberRole({
    required int barId,
    required String staffId,
    required String newRole,
  }) = _ChangeMemberRole;

  const factory StaffEvent.removeMember({
    required int barId,
    required String staffId,
  }) = _RemoveMember;
}
