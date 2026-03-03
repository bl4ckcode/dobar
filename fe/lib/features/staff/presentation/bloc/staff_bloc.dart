import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/staff_usecases.dart';
import 'staff_event.dart';
import 'staff_state.dart';

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final GetStaffMembersUseCase getStaffMembers;
  final InviteStaffUseCase inviteStaffMember;
  final UpdateStaffRoleUseCase updateStaffRole;
  final RemoveStaffUseCase removeStaffMember;

  StaffBloc({
    required this.getStaffMembers,
    required this.inviteStaffMember,
    required this.updateStaffRole,
    required this.removeStaffMember,
  }) : super(const StaffState.initial()) {
    on<StaffEvent>((event, emit) async {
      await event.map(
        loadStaff: (e) => _onLoadStaff(e.barId, emit),
        inviteMember: (e) => _onInviteMember(e.barId, e.contact, e.role, emit),
        changeMemberRole: (e) =>
            _onChangeMemberRole(e.barId, e.staffId, e.newRole, emit),
        removeMember: (e) => _onRemoveMember(e.barId, e.staffId, emit),
      );
    });
  }

  Future<void> _onLoadStaff(int barId, Emitter<StaffState> emit) async {
    emit(const StaffState.loading());
    try {
      final staff = await getStaffMembers(barId);
      emit(StaffState.loaded(staffMembers: staff));
    } catch (e) {
      emit(StaffState.error(message: 'Failed to load staff members.'));
    }
  }

  Future<void> _onInviteMember(
    int barId,
    String contact,
    String role,
    Emitter<StaffState> emit,
  ) async {
    final currentState = state;
    final staffList = currentState.maybeMap(
      loaded: (s) => s.staffMembers,
      actionSuccess: (s) => s.staffMembers,
      orElse: () => null,
    );
    if (staffList == null) return;

    emit(const StaffState.loading());
    try {
      await inviteStaffMember(barId: barId, contact: contact, role: role);
      final staff = await getStaffMembers(barId);
      emit(
        StaffState.actionSuccess(
          message: 'Invitation sent successfully.',
          staffMembers: staff,
        ),
      );
    } catch (e) {
      emit(StaffState.error(message: 'Failed to invite staff member.'));
      emit(StaffState.loaded(staffMembers: staffList));
    }
  }

  Future<void> _onChangeMemberRole(
    int barId,
    String staffId,
    String newRole,
    Emitter<StaffState> emit,
  ) async {
    final currentState = state;
    final staffList = currentState.maybeMap(
      loaded: (s) => s.staffMembers,
      actionSuccess: (s) => s.staffMembers,
      orElse: () => null,
    );
    if (staffList == null) return;

    emit(const StaffState.loading());
    try {
      await updateStaffRole(barId: barId, staffId: staffId, newRole: newRole);
      final staff = await getStaffMembers(barId);
      emit(
        StaffState.actionSuccess(
          message: 'Role updated successfully.',
          staffMembers: staff,
        ),
      );
    } catch (e) {
      emit(StaffState.error(message: 'Failed to update role.'));
      emit(StaffState.loaded(staffMembers: staffList));
    }
  }

  Future<void> _onRemoveMember(
    int barId,
    String staffId,
    Emitter<StaffState> emit,
  ) async {
    final currentState = state;
    final staffList = currentState.maybeMap(
      loaded: (s) => s.staffMembers,
      actionSuccess: (s) => s.staffMembers,
      orElse: () => null,
    );
    if (staffList == null) return;

    emit(const StaffState.loading());
    try {
      await removeStaffMember(barId: barId, staffId: staffId);
      final staff = await getStaffMembers(barId);
      emit(
        StaffState.actionSuccess(
          message: 'Staff member removed successfully.',
          staffMembers: staff,
        ),
      );
    } catch (e) {
      emit(StaffState.error(message: 'Failed to remove staff member.'));
      emit(StaffState.loaded(staffMembers: staffList));
    }
  }
}
