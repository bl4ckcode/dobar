import '../repositories/staff_repository.dart';
import '../models/bar_staff.dart';

class GetStaffMembersUseCase {
  final StaffRepository repository;

  GetStaffMembersUseCase(this.repository);

  Future<List<BarStaff>> call(int barId) {
    return repository.getStaffMembers(barId);
  }
}

class InviteStaffUseCase {
  final StaffRepository repository;

  InviteStaffUseCase(this.repository);

  Future<String> call({
    required int barId,
    required String contact,
    required String role,
  }) {
    return repository.inviteStaffMember(
      barId: barId,
      contact: contact,
      role: role,
    );
  }
}

class UpdateStaffRoleUseCase {
  final StaffRepository repository;

  UpdateStaffRoleUseCase(this.repository);

  Future<BarStaff> call({
    required int barId,
    required String staffId,
    required String newRole,
  }) {
    return repository.updateStaffRole(
      barId: barId,
      staffId: staffId,
      newRole: newRole,
    );
  }
}

class RemoveStaffUseCase {
  final StaffRepository repository;

  RemoveStaffUseCase(this.repository);

  Future<void> call({required int barId, required String staffId}) {
    return repository.removeStaffMember(barId: barId, staffId: staffId);
  }
}
