import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/utils/injections.dart';
import 'data/datasources/staff_remote_data_source.dart';
import 'data/repositories/staff_repository_impl.dart';
import 'domain/repositories/staff_repository.dart';
import 'domain/usecases/staff_usecases.dart';
import 'presentation/bloc/staff_bloc.dart';

void initStaff() {
  getItInjector.registerLazySingleton<StaffRemoteDataSource>(
    () => StaffRemoteDataSourceImpl(dio: DioNetwork.appAPI),
  );

  getItInjector.registerLazySingleton<StaffRepository>(
    () => StaffRepositoryImpl(
      remoteDataSource: getItInjector<StaffRemoteDataSource>(),
    ),
  );

  getItInjector.registerLazySingleton(
    () => GetStaffMembersUseCase(getItInjector<StaffRepository>()),
  );
  getItInjector.registerLazySingleton(
    () => InviteStaffUseCase(getItInjector<StaffRepository>()),
  );
  getItInjector.registerLazySingleton(
    () => UpdateStaffRoleUseCase(getItInjector<StaffRepository>()),
  );
  getItInjector.registerLazySingleton(
    () => RemoveStaffUseCase(getItInjector<StaffRepository>()),
  );

  getItInjector.registerFactory(
    () => StaffBloc(
      getStaffMembers: getItInjector<GetStaffMembersUseCase>(),
      inviteStaffMember: getItInjector<InviteStaffUseCase>(),
      updateStaffRole: getItInjector<UpdateStaffRoleUseCase>(),
      removeStaffMember: getItInjector<RemoveStaffUseCase>(),
    ),
  );
}
