import '../models/bar_staff.dart';

abstract class StaffRepository {
  Future<List<BarStaff>> getStaffMembers(int barId);
  Future<String> inviteStaffMember({
    required int barId,
    required String contact,
    required String role,
  });
  Future<BarStaff> updateStaffRole({
    required int barId,
    required String staffId,
    required String newRole,
  });
  Future<void> removeStaffMember({required int barId, required String staffId});
}
