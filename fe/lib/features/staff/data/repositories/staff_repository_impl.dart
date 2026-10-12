import '../../domain/models/bar_staff.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_remote_data_source.dart';

class StaffRepositoryImpl implements StaffRepository {
  final StaffRemoteDataSource remoteDataSource;

  StaffRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<BarStaff>> getStaffMembers(int barId) {
    return remoteDataSource.getStaffMembers(barId);
  }

  @override
  Future<String> inviteStaffMember({
    required int barId,
    required String contact,
    required String role,
  }) {
    return remoteDataSource.inviteStaffMember(
      barId: barId,
      contact: contact,
      role: role,
    );
  }

  @override
  Future<BarStaff> updateStaffRole({
    required int barId,
    required String staffId,
    required String newRole,
  }) {
    return remoteDataSource.updateStaffRole(
      barId: barId,
      staffId: staffId,
      newRole: newRole,
    );
  }

  @override
  Future<void> removeStaffMember({
    required int barId,
    required String staffId,
  }) {
    return remoteDataSource.removeStaffMember(barId: barId, staffId: staffId);
  }
}
