import 'package:get_it/get_it.dart';
import 'data/datasources/staff_remote_data_source.dart';
import 'data/repositories/staff_repository_impl.dart';
import 'domain/repositories/staff_repository.dart';
import 'domain/usecases/staff_usecases.dart';
import 'presentation/bloc/staff_bloc.dart';
import 'package:dio/dio.dart';

final sl = GetIt.instance;

void initStaff() {
  // Remote Data Source
  sl.registerLazySingleton<StaffRemoteDataSource>(
    () => StaffRemoteDataSourceImpl(dio: sl<Dio>()),
  );

  // Repository
  sl.registerLazySingleton<StaffRepository>(
    () => StaffRepositoryImpl(remoteDataSource: sl()),
  );

  // UseCases
  sl.registerLazySingleton(() => GetStaffMembersUseCase(sl()));
  sl.registerLazySingleton(() => InviteStaffUseCase(sl()));
  sl.registerLazySingleton(() => UpdateStaffRoleUseCase(sl()));
  sl.registerLazySingleton(() => RemoveStaffUseCase(sl()));

  // BLoC
  sl.registerFactory(
    () => StaffBloc(
      getStaffMembers: sl(),
      inviteStaffMember: sl(),
      updateStaffRole: sl(),
      removeStaffMember: sl(),
    ),
  );
}
