import 'package:dio/dio.dart';
import 'package:barz/core/rbac/rbac.dart';
import '../../domain/models/bar_staff.dart';

abstract class StaffRemoteDataSource {
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

class StaffRemoteDataSourceImpl implements StaffRemoteDataSource {
  final Dio dio;

  StaffRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<BarStaff>> getStaffMembers(int barId) async {
    final response = await dio.get('/bars/$barId/staff');
    return (response.data as List)
        .map((json) => BarStaff.fromJson(json))
        .toList();
  }

  @override
  Future<String> inviteStaffMember({
    required int barId,
    required String contact,
    required String role,
  }) async {
    final response = await dio.post(
      '/bars/$barId/staff/invite',
      data: {'contact': contact, 'role': role},
    );
    return response.data['invite_id'] as String;
  }

  @override
  Future<BarStaff> updateStaffRole({
    required int barId,
    required String staffId,
    required String newRole,
  }) async {
    await dio.put('/bars/$barId/staff/$staffId/role', data: {'role': newRole});
    // Real implementation would return the full BarStaff,
    // but the API docs show "{message: ..., staff_id: ..., new_role: ...}".
    // By convention, we might need to mock or return a stub if the backend doesn't return full details,
    // or we fetch the updated list afterward. For now, returning a stub.
    return BarStaff(
      id: staffId,
      name: 'Unknown',
      email: '',
      phone: '',
      role: BarRole.values.firstWhere(
        (e) => e.name == newRole,
        orElse: () => BarRole.staff,
      ),
    );
  }

  @override
  Future<void> removeStaffMember({
    required int barId,
    required String staffId,
  }) async {
    await dio.delete('/bars/$barId/staff/$staffId');
  }
}
